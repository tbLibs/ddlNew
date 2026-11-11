import Foundation
@MainActor final class UIApplication { static let shared = UIApplication(); var isIdleTimerDisabled = false }
enum AVAudioSession {
 static let interruptionNotification = Notification.Name("OfflineInterruption")
 enum InterruptionType: UInt { case began = 1 }
}
let AVAudioSessionInterruptionTypeKey = "type"
let kSystemSoundID_Vibrate: UInt32 = 4095
func AudioServicesPlaySystemSound(_ value: UInt32) {}
var ringtoneCompletions: [() -> Void] = []
var ringtoneSounds: [UInt32] = []
func AudioServicesPlaySystemSoundWithCompletion(_ value: UInt32, _ completion: @escaping () -> Void) {
 ringtoneSounds.append(value)
 ringtoneCompletions.append(completion)
}
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
  resources.startRinging(incoming: false)
  precondition(ringtoneSounds == [1004], "outgoing uses xgd system tone")
  ringtoneCompletions.removeFirst()()
  for _ in 0..<20 { await Task.yield() }
  precondition(ringtoneSounds == [1004, 1004], "tone repeats when playback completes")
  ringtoneCompletions.removeFirst()()
  resources.stopRinging()
  for _ in 0..<20 { await Task.yield() }
  precondition(ringtoneSounds.count == 2, "queued completion cannot restart stopped tone")
  resources.startRinging(incoming: false)
  let oldCompletion = ringtoneCompletions.removeFirst()
  resources.startRinging(incoming: true)
  oldCompletion()
  for _ in 0..<20 { await Task.yield() }
  precondition(ringtoneSounds.count == 4, "old call cannot start a second loop for replacement call")
  resources.release()
  ringtoneCompletions.removeFirst()()
  for _ in 0..<20 { await Task.yield() }
  precondition(ringtoneSounds.count == 4, "released call cannot resume ringing")
  UIApplication.shared.isIdleTimerDisabled = true
  resources.startRinging(incoming: true); resources.release()
  precondition(UIApplication.shared.isIdleTimerDisabled, "restore previous screen ownership")
  print("Calls: system resource ownership checks passed")
 }
}
