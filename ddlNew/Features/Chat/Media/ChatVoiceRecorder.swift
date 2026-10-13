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
    @Published var errorMessage: String?
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var generation = UUID()
    private var file: URL?
    private var context: ChatContext?
    private var interruptionObserver: NSObjectProtocol?

    /// 麦克风授权返回后再次校验认证轮次，取消授权等待不会启动录音。
    func start(context: ChatContext) async {
        cancel(); errorMessage = nil; self.context = context; let run = generation
        let session = AVAudioSession.sharedInstance()
        let permitted = await withCheckedContinuation { continuation in session.requestRecordPermission { continuation.resume(returning: $0) } }
        guard generation == run, ChatRuntime.shared.isCurrent(context) else { return }
        guard permitted else { errorMessage = "麦克风权限未开启，请在系统设置中允许录音"; return }
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP]); try session.setActive(true)
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
            let recorder = try AVAudioRecorder(url: file, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64000])
            recorder.delegate = self
            guard recorder.record(forDuration: 60) else { throw ChatClientError.unavailable("无法开始录音，请重试") }
            self.recorder = recorder; self.file = file; isRecording = true; duration = 0
            observeInterruption()
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let owner = self else { return }
                Task { @MainActor in owner.updateDuration() }
            }
        } catch { errorMessage = error.localizedDescription; cancel() }
    }

    /// 计时器只在主actor读取录音状态，不从系统定时回调访问可变属性。
    private func updateDuration() { duration = recorder?.currentTime ?? duration }

    /// 停止保留录音供用户发送或取消，不自动触发上传。
    func stopRecording() {
        duration = max(duration, recorder?.currentTime ?? 0); recorder?.stop()
        timer?.invalidate(); timer = nil; isRecording = false
    }

    /// 用户确认才产生语音附件，未满足1024字节或超过60秒不发送。
    func finish() throws -> ChatAttachment {
        guard let recorder, let file, let context, ChatRuntime.shared.isCurrent(context) else { throw ChatClientError.sessionExpired }
        duration = max(duration, recorder.currentTime); recorder.stop(); timer?.invalidate(); timer = nil; isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let bytes = Int64(try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        guard bytes >= 1024, duration > 0, duration <= 60.5 else { try? FileManager.default.removeItem(at: file); throw ChatClientError.unavailable("录音太短，请重新录制") }
        self.file = nil; self.recorder = nil
        return ChatAttachment(file: file, type: 4, name: file.lastPathComponent, bytes: bytes, duration: min(60, duration))
    }

    /// 达60秒停录后仍等待用户确认发送，不自动声称消息成功。
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            guard self.recorder === recorder else { return }
            self.timer?.invalidate(); self.timer = nil; self.isRecording = false
            if flag { self.duration = min(60, max(self.duration, recorder.currentTime)); self.errorMessage = "录音已停止，请发送或取消" }
            else { self.errorMessage = "录音被中断，请重新录制"; self.cancel() }
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
        generation = UUID(); timer?.invalidate(); timer = nil; recorder?.stop(); recorder = nil
        if let file { try? FileManager.default.removeItem(at: file) }; file = nil; context = nil
        isRecording = false; duration = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
