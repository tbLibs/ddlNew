import Foundation
import CoreGraphics

// UIKit/SwiftUI boundary only. Production sync, drag and clamp methods are compiled unchanged.
struct UIEdgeInsets { var top: CGFloat = 0; var left: CGFloat = 0; var bottom: CGFloat = 0; var right: CGFloat = 0 }
extension CGRect {
    func inset(by i: UIEdgeInsets) -> CGRect {
        CGRect(x: minX + i.left, y: minY + i.top, width: width - i.left - i.right, height: height - i.top - i.bottom)
    }
}
enum UIColor { case clear }
@MainActor class UIView {
    var frame = CGRect.zero
    var bounds: CGRect { CGRect(origin: .zero, size: frame.size) }
    var center: CGPoint {
        get { CGPoint(x: frame.midX, y: frame.midY) }
        set { frame.origin = CGPoint(x: newValue.x - frame.width / 2, y: newValue.y - frame.height / 2) }
    }
    var backgroundColor: UIColor?
    var safeAreaInsets = UIEdgeInsets()
    weak var owner: UIViewController?
    weak var superview: UIView?
    var subviews: [UIView] = []
    var window: UIWindow? { (self as? UIWindow) ?? superview?.window }
    var containmentViolations = 0
    func addSubview(_ view: UIView) {
        // A controller view attached directly to UIWindow must not claim a different parent.
        if self is UIWindow, view.owner?.parent != nil { containmentViolations += 1 }
        view.removeFromSuperview(); subviews.append(view); view.superview = self
    }
    func removeFromSuperview() {
        superview?.subviews.removeAll { $0 === self }; superview = nil
    }
    func bringSubviewToFront(_ view: UIView) {
        guard view.superview === self else { return }
        subviews.removeAll { $0 === view }; subviews.append(view)
    }
    func addGestureRecognizer(_ gesture: UIPanGestureRecognizer) {}
}
@MainActor class UIWindow: UIView {}
@MainActor class UIViewController {
    lazy var view: UIView = { let view = UIView(); view.owner = self; return view }()
    var viewIfLoaded: UIView? { view }
    weak var parent: UIViewController?
    var children: [UIViewController] = []
    func addChild(_ child: UIViewController) { children.append(child); child.parent = self }
    func willMove(toParent: UIViewController?) {}
    func didMove(toParent: UIViewController?) {}
    func removeFromParent() { parent?.children.removeAll { $0 === self }; parent = nil }
}
@MainActor final class UIHostingController<Content>: UIViewController {
    var rootView: Content
    init(rootView: Content) { self.rootView = rootView }
}
@MainActor final class UIPanGestureRecognizer {
    var offset = CGPoint.zero
    init(target: AnyObject, action: String) {}
    func translation(in: UIView) -> CGPoint { offset }
    func setTranslation(_ point: CGPoint, in: UIView) { offset = point }
}
@MainActor final class CallCoordinator {}
struct CallFloatingView { let coordinator: CallCoordinator }

@main struct PresentationChecks {
    @MainActor static func main() {
        var failures = 0
        var checks = 0
        func check(_ condition: Bool, _ name: String) {
            checks += 1
            if !condition { failures += 1 }
            print("\(condition ? "PASS" : "FAIL") \(name)")
        }
        let window = UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.safeAreaInsets = UIEdgeInsets(top: 47, bottom: 34)
        let controller = CallPresentationHarness()
        window.addSubview(controller.view)
        controller.sceneWindow = window
        controller.syncBubble()
        check(window.containmentViolations == 0, "minimize respects window/controller containment")
        check(controller.bubble?.view.superview === window, "floating view stays on scene window")
        weak var first = controller.bubble
        check(first != nil, "presentation controller retains floating host")
        let gesture = UIPanGestureRecognizer(target: controller, action: "dragBubble:")
        gesture.offset = CGPoint(x: -10_000, y: 10_000)
        controller.dragBubble(gesture)
        check(controller.bubble?.view.frame.minX == 8 && controller.bubble?.view.frame.maxY == 802,
              "drag clamps to safe area")
        let draggedFrame = controller.bubble?.view.frame
        controller.syncBubble()
        check(controller.bubble === first && controller.bubble?.view.frame == draggedFrame && window.subviews.count == 2,
              "updates reuse one host and preserve position")
        controller.floating = false
        controller.syncBubble()
        check(first == nil && controller.bubble == nil && window.subviews.count == 1 && controller.children.isEmpty,
              "restore removes and releases floating host")
        for _ in 0..<10 {
            controller.floating = true; controller.syncBubble()
            controller.floating = false; controller.syncBubble()
        }
        check(window.containmentViolations == 0 && window.subviews.count == 1 && controller.children.isEmpty,
              "repeated minimize/restore leaves no containment violations or orphan views")
        controller.view.removeFromSuperview()
        controller.floating = true; controller.syncBubble()
        check(controller.bubble?.view.superview === window, "cached scene window supports temporarily detached anchor")
        weak var last = controller.bubble
        controller.attached = false; controller.syncBubble()
        check(last == nil && window.subviews.isEmpty && controller.children.isEmpty, "teardown releases floating host")
        controller.attached = true; controller.sceneWindow = nil; controller.syncBubble()
        check(controller.bubble == nil, "no window creates no floating host")
        print("\(checks - failures)/\(checks) presentation checks passed")
        if failures > 0 { exit(1) }
    }
}
