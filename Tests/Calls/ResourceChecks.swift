import Foundation
@MainActor final class UIApplication { static let shared = UIApplication(); var isIdleTimerDisabled = false }
enum AVAudioSession {
 static let interruptionNotification = Notification.Name("OfflineInterruption")
 enum InterruptionType: UInt { case began = 1 }
}
let AVAudioSessionInterruptionTypeKey = "type"
let kSystemSoundID_Vibrate: UInt32 = 4095
func AudioServicesPlaySystemSound(_ value: UInt32) {}
@main struct ResourceChecks {
 @MainActor static func main() async {
  let resources = CallSystemResources(); var callbacks = 0
  resources.interrupted = { callbacks += 1 }
  resources.retainScreen()
  precondition(UIApplication.shared.isIdleTimerDisabled)
  NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: UInt(1)])
  resources.release()
  precondition(!UIApplication.shared.isIdleTimerDisabled)
  resources.retainScreen()
  for _ in 0..<20 { await Task.yield() }
  precondition(callbacks == 0, "queued previous interruption must not affect replacement call")
  NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: UInt(1)])
  for _ in 0..<20 { await Task.yield() }
  precondition(callbacks == 1, "current interruption must reach owner")
  resources.release()
  UIApplication.shared.isIdleTimerDisabled = true
  resources.startRinging(incoming: true); resources.release()
  precondition(UIApplication.shared.isIdleTimerDisabled, "restore previous screen ownership")
  print("Calls: system resource ownership checks passed")
 }
}
