import Foundation
import CoreGraphics

@main struct FloatingPositionChecks {
    static func main() {
        let size = CGSize(width: 390, height: 844)
        var state = MiniAppFloatingPosition()
        precondition(state.position(in: size) == CGPoint(x: 358, y: 100))
        state.update(translation: CGSize(width: -90, height: 70), in: size)
        precondition(state.position(in: size) == CGPoint(x: 268, y: 170), "拖动中必须连续跟随横纵位移")
        precondition(!state.finish(translation: CGSize(width: -90, height: 70), in: size), "拖动松手不能打开")
        precondition(state.position(in: size) == CGPoint(x: 358, y: 170), "仅松手后贴边")
        state.update(translation: CGSize(width: -220, height: 50), in: size)
        precondition(state.position(in: size) == CGPoint(x: 138, y: 220), "下次拖动以停靠位置为起点")
        precondition(!state.finish(translation: .zero, in: size), "拖出再回原点仍是拖动，不能误触点击")
        precondition(state.finish(translation: CGSize(width: 2, height: 1), in: size), "单独轻点允许微小抖动")
        state.update(translation: CGSize(width: -1000, height: 1000), in: size)
        precondition(state.position(in: size) == CGPoint(x: 32, y: 724), "安全区约束")
        precondition(!state.finish(translation: CGSize(width: -1000, height: 1000), in: size))
        precondition(state.position(in: CGSize(width: 320, height: 480)) == CGPoint(x: 32, y: 360), "尺寸变化不能把浮窗留在屏外")
        print("PASS: continuous drag, release without opening, docking, return-to-origin, separate tap, bounds")
    }
}
