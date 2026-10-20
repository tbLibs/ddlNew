//
//  ChatVoiceRecorder.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import AVFoundation
import Combine

@MainActor final class ChatVoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var duration = 0.0
    @Published private(set) var level = 0.0
    @Published var errorMessage: String?
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var generation = UUID()
    private var file: URL?
    private var context: ChatContext?
    private var interruptionObserver: NSObjectProtocol?
    private var ownsAudioSession = false
    private var onLimitReached: (() -> Void)?

    /// 麦克风授权返回后再次校验认证轮次，取消授权等待不会启动录音。
    func start(context: ChatContext, onLimitReached: (() -> Void)? = nil) async {
        cancel(); errorMessage = nil; self.context = context; let run = generation
        self.onLimitReached = onLimitReached
        let session = AVAudioSession.sharedInstance()
        let permitted = await withCheckedContinuation { continuation in session.requestRecordPermission { continuation.resume(returning: $0) } }
        guard generation == run, !Task.isCancelled, ChatRuntime.shared.isCurrent(context) else { return }
        guard permitted else { errorMessage = "麦克风权限未开启，请在系统设置中允许录音"; return }
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP]); try session.setActive(true)
            ownsAudioSession = true
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
            self.file = file
            let recorder = try AVAudioRecorder(url: file, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64000])
            self.recorder = recorder; recorder.delegate = self; recorder.isMeteringEnabled = true
            guard recorder.record(forDuration: 60) else { throw ChatClientError.unavailable("无法开始录音，请重试") }
            self.recorder = recorder; self.file = file; isRecording = true; duration = 0
            observeInterruption()
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let owner = self else { return }
                Task { @MainActor in guard owner.generation == run else { return }; owner.updateDuration() }
            }
            self.timer = timer; RunLoop.main.add(timer, forMode: .common)
        } catch { errorMessage = error.localizedDescription; cancel() }
    }

    /// 计时器只在主actor读取录音状态，不从系统定时回调访问可变属性。
    private func updateDuration() {
        guard let recorder, isRecording else { return }
        duration = min(60, max(duration, recorder.currentTime))
        recorder.updateMeters()
        level = min(1, max(0, pow(10, Double(recorder.averagePower(forChannel: 0)) / 40)))
    }

    /// 松手或到达上限时交付一次；与旧端一致，不足一秒不发送。
    func finish() throws -> ChatAttachment {
        guard let recorder, let file, let context, ChatRuntime.shared.isCurrent(context) else { throw ChatClientError.sessionExpired }
        onLimitReached = nil
        duration = max(duration, recorder.currentTime); recorder.stop(); timer?.invalidate(); timer = nil; isRecording = false
        releaseAudioSession()
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }; interruptionObserver = nil
        let bytes = Int64(try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        guard bytes >= 1024, duration >= 1, duration <= 60.5 else { cancel(); throw ChatClientError.unavailable("说话时间太短") }
        self.file = nil; self.recorder = nil; self.context = nil
        return ChatAttachment(file: file, type: 4, name: file.lastPathComponent, bytes: bytes, duration: min(60, duration))
    }

    /// 系统到60秒结束只发布一次发送意图；随后松手不能再次交付附件。
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            guard self.recorder === recorder else { return }
            self.timer?.invalidate(); self.timer = nil; self.isRecording = false
            if flag {
                self.duration = 60
                let completion = self.onLimitReached; self.onLimitReached = nil
                completion?()
            }
            else { self.errorMessage = "录音被中断，请重新录制"; self.cancel() }
        }
    }

    /// 只归还本录音器取得的音频会话，空闲取消不能停止聊天中的播放。
    private func releaseAudioSession() {
        guard ownsAudioSession else { return }
        ownsAudioSession = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// 编码失败与系统中断一样清理未交付文件，迟到回调不影响新录音。
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            guard self.recorder === recorder else { return }
            self.cancel(); self.errorMessage = "录音出错了，请稍后再试"
        }
    }

    /// 电话或系统中断停止并删除未发送录音，不能上传残缺资源。
    private func observeInterruption() {
        let run = generation
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let began = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue == AVAudioSession.InterruptionType.began.rawValue
            guard began, let owner = self else { return }
            Task { @MainActor in guard owner.generation == run else { return }; owner.cancel(); owner.errorMessage = "录音被系统中断，请重新录制" }
        }
    }

    /// 上滑/取消、后台及离页都删除未发送文件并释放音频会话。
    func cancel() {
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }; interruptionObserver = nil
        generation = UUID(); onLimitReached = nil; timer?.invalidate(); timer = nil; recorder?.stop(); recorder = nil
        if let file { try? FileManager.default.removeItem(at: file) }; file = nil; context = nil
        isRecording = false; duration = 0; level = 0
        releaseAudioSession()
    }
}
