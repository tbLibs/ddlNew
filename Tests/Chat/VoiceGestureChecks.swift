import Foundation
import CoreGraphics

class UIControl {
    var isEnabled = true
    var bounds = CGRect(x: 0, y: 0, width: 248, height: 44)
    func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool { false }
    func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool { false }
    func endTracking(_ touch: UITouch?, with event: UIEvent?) {}
    func cancelTracking(with event: UIEvent?) {}
    func accessibilityActivate() -> Bool { false }
}
struct UITouch {
    let point: CGPoint
    init(_ x: CGFloat, _ y: CGFloat) { point = CGPoint(x: x, y: y) }
    func location(in view: UIControl) -> CGPoint { point }
}
class UIEvent {}

@main struct VoiceGestureChecks {
    static func main() {
        let control = VoiceControl()
        var begins = 0, cancels = 0
        var moves: [Bool] = [], ends: [Bool] = []
        control.onBegin = { begins += 1 }
        control.onMove = { moves.append($0) }
        control.onEnd = { ends.append($0) }
        control.onCancel = { cancels += 1 }
        precondition(control.beginTracking(UITouch(120, 2), with: nil))
        _ = control.continueTracking(UITouch(120, -6), with: nil)
        precondition(moves.last == true, "靠近上沿按住时，小幅抖动不应进入取消")
        _ = control.continueTracking(UITouch(300, 2), with: nil)
        precondition(moves.last == true, "水平偏移不应误触发上滑取消")
        _ = control.continueTracking(UITouch(120, -57), with: nil)
        precondition(moves.last == true, "上滑59pt仍可发送")
        _ = control.continueTracking(UITouch(120, -58), with: nil)
        precondition(moves.last == false, "上滑60pt进入取消")
        _ = control.continueTracking(UITouch(120, -30), with: nil)
        precondition(moves.last == true, "滑回可继续录音")
        control.endTracking(UITouch(120, -30), with: nil)
        precondition(ends == [true])
        _ = control.beginTracking(UITouch(120, 40), with: nil)
        control.endTracking(UITouch(120, -20), with: nil)
        precondition(ends == [true, false], "结束时按最终位置判断，不能依赖上次move")
        _ = control.beginTracking(UITouch(120, 22), with: nil)
        control.endTracking(nil, with: nil)
        precondition(ends.last == false, "触摸丢失不得发送")
        _ = control.beginTracking(UITouch(120, 22), with: nil)
        control.cancelTracking(with: nil)
        precondition(cancels == 1)
        control.isEnabled = false
        precondition(!control.beginTracking(UITouch(120, 22), with: nil))
        precondition(begins == 4 && !control.accessibilityActivate())
        control.isEnabled = true
        control.holding = false
        precondition(control.accessibilityActivate() && begins == 5)
        control.holding = true
        precondition(control.accessibilityActivate() && ends.last == true)
        precondition(control.cancelAccessibleRecording() && cancels == 2)
        print("Voice gesture tracking checks passed")
    }
}
