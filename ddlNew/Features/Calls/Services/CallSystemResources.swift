//
//  CallSystemResources.swift
//  ddlNew
//
//  Created by taobo on 2026/10/20.
//

import AVFoundation
import AudioToolbox
import UIKit

/// 铃声、屏幕常亮和权限由当前通话拥有，清理不依赖之后变化的配置开关。
@MainActor final class CallSystemResources {
    private var ringtone: Timer?
    private var previousIdleTimer: Bool?
    private var generation = UUID()
    private var interruption: NSObjectProtocol?
    var interrupted: (() -> Void)?

    func startRinging(incoming: Bool) {
        stopRinging()
        retainScreen()
        AudioServicesPlaySystemSound(1004)
        if incoming { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
        ringtone = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            AudioServicesPlaySystemSound(1004)
            if incoming { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
        }
    }
    func stopRinging() { ringtone?.invalidate(); ringtone = nil }
    func retainScreen() {
        if previousIdleTimer == nil { previousIdleTimer = UIApplication.shared.isIdleTimerDisabled; UIApplication.shared.isIdleTimerDisabled = true }
        if interruption == nil {
            let stamp = generation
            interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
                guard let value = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt, value == AVAudioSession.InterruptionType.began.rawValue else { return }
                Task { @MainActor [weak self] in guard let self, self.generation == stamp else { return }; self.interrupted?() }
            }
        }
    }
    func release() {
        generation = UUID()
        stopRinging()
        if let previousIdleTimer { UIApplication.shared.isIdleTimerDisabled = previousIdleTimer }
        previousIdleTimer = nil
        if let interruption { NotificationCenter.default.removeObserver(interruption) }
        interruption = nil
    }
    static func requestPermission(kind: CallKind) async throws {
        let microphone: Bool
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: microphone = true
        case .denied: microphone = false
        case .undetermined: microphone = await withCheckedContinuation { continuation in AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) } }
        @unknown default: microphone = false
        }
        guard microphone else { throw CallError.unavailable("请在系统设置中允许麦克风权限后通话") }
        try Task.checkCancellation()
        if kind == .video {
            let camera: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: camera = true
            case .notDetermined: camera = await AVCaptureDevice.requestAccess(for: .video)
            default: camera = false
            }
            guard camera else { throw CallError.unavailable("请在系统设置中允许相机权限后视频通话") }
        }
    }
}
