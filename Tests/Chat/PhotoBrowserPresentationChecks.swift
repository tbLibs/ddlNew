import Foundation

// 不启动设备；验证真实控制器的呈现配置和转场期间状态收敛，不能替代视觉验收。
struct ChatContext: Equatable { let id: Int }
enum ScenePhase { case active, inactive, background }
struct ChatPhotoBrowserRequest { let id: String }
struct ChatPhotoBrowserView {
    let id: String
    var scenePhase: ScenePhase
    init(id: String, scenePhase: ScenePhase = .active) { self.id = id; self.scenePhase = scenePhase }
    // 对照 SwiftUI 新环境的默认 background；实际桥接必须显式传入父场景状态。
    init(gallery: ChatPhotoBrowserRequest, context: ChatContext, allowSharing: Bool,
         includeCachedHistory: Bool, scenePhase: ScenePhase = .background, onClose: @escaping () -> Void) {
        id = gallery.id; self.scenePhase = scenePhase
    }
}
enum TestColor { case clear, black }
enum TestPresentationStyle { case fullScreen, overFullScreen }
enum TestTransitionStyle { case coverVertical, crossDissolve }
@MainActor final class TestView {
    var window: Bool?
    var backgroundColor = TestColor.black
    var isOpaque = true
}
@MainActor class UIViewController {
    let view = TestView()
    var viewIfLoaded: TestView? { view }
    var presentedViewController: UIViewController?
    weak var presenter: UIViewController?
    var completion: (() -> Void)?
    var modalPresentationStyle = TestPresentationStyle.fullScreen
    var modalTransitionStyle = TestTransitionStyle.coverVertical
    var modalPresentationCapturesStatusBarAppearance = false
    var presentations = 0
    var dismissals = 0
    var lastDismissAnimated: Bool?
    func viewDidLoad() {}
    func viewDidAppear(_ animated: Bool) {}
    func present(_ controller: UIViewController, animated: Bool, completion: @escaping () -> Void) {
        precondition(presentedViewController == nil)
        presentations += 1
        presentedViewController = controller
        controller.presenter = self
        self.completion = completion
    }
    func dismiss(animated: Bool, completion: @escaping () -> Void) {
        dismissals += 1
        lastDismissAnimated = animated
        self.completion = { [self] in
            presenter?.presentedViewController = nil
            presenter = nil
            completion()
        }
    }
    func finishTransition() { let done = completion; completion = nil; done?() }
}
@MainActor final class UIHostingController<Content>: UIViewController {
    var rootView: Content
    init(rootView: Content) { self.rootView = rootView }
}

@main struct PhotoBrowserPresentationChecks {
    @MainActor static func main() {
        var count = 0
        var failures = 0
        func check(_ value: Bool, _ label: String) {
            count += 1
            if !value { failures += 1 }
            print("\(value ? "PASS" : "FAIL") \(label)")
        }
        let bridge = PresentationBridgeHarness()
        let bridged = ChatPhotoBrowserPresentationController()
        bridged.view.window = true
        bridge.updateUIViewController(bridged, context: .init())
        let bridgedHost = bridged.presentedViewController as! UIHostingController<ChatPhotoBrowserView>
        check(bridgedHost.rootView.scenePhase == .active, "真实桥接首次呈现显式传入前台状态，避免默认后台黑屏")
        bridged.finishTransition()
        bridge.scenePhase = .background
        bridge.updateUIViewController(bridged, context: .init())
        check(bridgedHost.rootView.scenePhase == .background, "真实桥接同步父页面进入后台")
        bridge.scenePhase = .active
        bridge.updateUIViewController(bridged, context: .init())
        check(bridgedHost.rootView.scenePhase == .active && bridged.presentations == 1,
              "真实桥接同步父页面回前台且不重复弹出")
        bridged.detach(); bridgedHost.finishTransition()
        let first = ChatPhotoBrowserPresentationController.Identity(messageID: "one", context: .init(id: 1))
        let second = ChatPhotoBrowserPresentationController.Identity(messageID: "two", context: .init(id: 1))
        let controller = ChatPhotoBrowserPresentationController()
        controller.viewDidLoad()
        controller.setContent(identity: first) { .init(id: "one") }
        check(controller.presentations == 0, "未挂到页面时不抢先呈现")
        controller.view.window = true
        controller.viewDidAppear(false)
        let host = controller.presentedViewController as! UIHostingController<ChatPhotoBrowserView>
        check(host.modalPresentationStyle == .overFullScreen, "预览覆盖时保留底下聊天画面")
        check(host.view.backgroundColor == .clear && !host.view.isOpaque && controller.view.backgroundColor == .clear,
              "呈现层没有额外不透明黑底")
        check(host.modalTransitionStyle == .crossDissolve, "退出不叠加整页下滑动画")
        controller.setContent(identity: first) { .init(id: "one", scenePhase: .inactive) }
        check(host.rootView.scenePhase == .inactive, "开场动画中场景状态变化立即传入预览")
        controller.setContent(identity: first) { .init(id: "one", scenePhase: .active) }
        check(host.rootView.scenePhase == .active, "前台恢复传入同一个预览容器")
        controller.setContent(identity: nil, makeContent: nil)
        check(host.dismissals == 0, "开场动画中收到关闭等待转场结束")
        controller.finishTransition()
        check(host.dismissals == 1, "开场完成后关闭请求不会丢失")
        controller.setContent(identity: second) { .init(id: "two") }
        check(controller.presentations == 1, "退出途中重开不叠加第二层遮罩")
        host.finishTransition()
        let next = controller.presentedViewController as! UIHostingController<ChatPhotoBrowserView>
        check(controller.presentations == 2 && next.rootView.id == "two", "旧层移除后只呈现最新请求")
        controller.finishTransition()
        controller.setContent(identity: second) { .init(id: "two") }
        check(controller.presentations == 2 && next.dismissals == 0, "重复刷新不重新呈现或关闭")
        controller.setContent(identity: second) { .init(id: "two", scenePhase: .background) }
        check(next.rootView.scenePhase == .background, "已打开的预览收到后台状态以停止加载播放")
        controller.setContent(identity: second) { .init(id: "two", scenePhase: .active) }
        check(next.rootView.scenePhase == .active && controller.presentations == 2 && next.dismissals == 0,
              "返回前台恢复内容而不重建呈现容器")
        controller.detach()
        check(next.dismissals == 1 && next.lastDismissAnimated == false, "父页面卸载立即清理覆盖层")
        next.finishTransition()
        check(controller.presentedViewController == nil, "关闭后没有残留呈现控制器")

        let detached = ChatPhotoBrowserPresentationController()
        detached.view.window = true
        detached.setContent(identity: first) { .init(id: "one") }
        let pending = detached.presentedViewController!
        detached.detach()
        detached.finishTransition()
        check(pending.dismissals == 1 && pending.lastDismissAnimated == false, "开场中父页面卸载也会完成清理")
        pending.finishTransition()
        check(detached.presentedViewController == nil, "卸载后的迟到转场不重新显示预览")
        print("Presentation checks: \(count - failures)/\(count)")
        if failures > 0 { exit(1) }
    }
}
