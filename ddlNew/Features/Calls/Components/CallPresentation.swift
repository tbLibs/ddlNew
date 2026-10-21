import SwiftUI
import UIKit

extension View {
    /// 挂在应用根场景，来电可以覆盖当前媒体或设置页。
    func callPresentation() -> some View { background(CallPresentation().frame(width: 0, height: 0)) }
}

private struct CallPresentation: UIViewControllerRepresentable {
    @ObservedObject private var coordinator = CallCoordinator.shared
    @Environment(\.scenePhase) private var scenePhase

    func makeUIViewController(context: Context) -> CallPresentationController { CallPresentationController() }

    func updateUIViewController(_ controller: CallPresentationController, context: Context) {
        let identity = coordinator.isPresented ? coordinator.session?.id : nil
        let selection = coordinator.session == nil ? coordinator.selection : nil
        controller.update(identity: identity ?? selection?.id,
                          floating: coordinator.session != nil && !coordinator.isPresented,
                          coordinator: coordinator, scenePhase: scenePhase)
    }

    static func dismantleUIViewController(_ controller: CallPresentationController, coordinator: ()) {
        controller.detach()
    }
}

/// 使用锚点所属窗口，不枚举其他 scene；UIKit 转场期间串行重试。
@MainActor private final class CallPresentationController: UIViewController {
    private var desiredID: UUID?
    private var shownID: UUID?
    private var coordinator: CallCoordinator?
    private var phase = ScenePhase.active
    private var floating = false
    private var attached = true
    private var transitioning = false
    private var hosting: CallHostingController?
    private let layout = CallLayoutPreferences()
    private var layoutSessionID: UUID?
    private var bubble: UIHostingController<CallFloatingView>?
    private var retry: DispatchWorkItem?
    private var feedback: UIHostingController<AnyView>?
    private var feedbackRemoval: DispatchWorkItem?
    private var lastError: String?
    private weak var sceneWindow: UIWindow?

    override func viewDidLoad() { super.viewDidLoad(); view.backgroundColor = .clear }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); synchronize() }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); clampBubble() }

    func update(identity: UUID?, floating: Bool, coordinator: CallCoordinator, scenePhase: ScenePhase) {
        desiredID = identity
        self.floating = floating
        self.coordinator = coordinator
        phase = scenePhase
        if layoutSessionID != coordinator.session?.id {
            layoutSessionID = coordinator.session?.id
            layout.prefersLocalVideo = false
        }
        if let window = viewIfLoaded?.window { sceneWindow = window }
        showFeedback(coordinator.errorMessage)
        if let hosting, identity == shownID { hosting.rootView = content(coordinator) }
        synchronize()
    }

    func detach() {
        attached = false; desiredID = nil; floating = false
        retry?.cancel(); retry = nil
        feedbackRemoval?.cancel(); feedbackRemoval = nil
        feedback?.view.removeFromSuperview(); feedback = nil
        synchronize()
    }

    private func showFeedback(_ message: String?) {
        guard message != lastError else { return }
        lastError = message
        guard let message, !message.isEmpty, let window = viewIfLoaded?.window ?? sceneWindow else { return }
        feedbackRemoval?.cancel()
        feedback?.view.removeFromSuperview()
        let host = UIHostingController(rootView: AnyView(Color.clear.messagingFeedbackToast(message, presentInitial: true)))
        host.view.backgroundColor = .clear; host.view.isUserInteractionEnabled = false
        host.view.frame = window.bounds; host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(host.view); feedback = host
        let removal = DispatchWorkItem { [weak self, weak host] in
            host?.view.removeFromSuperview()
            if self?.feedback === host { self?.feedback = nil }
        }
        feedbackRemoval = removal
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: removal)
    }

    private func content(_ coordinator: CallCoordinator) -> AnyView {
        if coordinator.session != nil {
            return AnyView(CallRoomView(coordinator: coordinator, layout: layout).environment(\.scenePhase, phase))
        }
        if let selection = coordinator.selection {
            return AnyView(CallMemberSelectionView(request: selection, coordinator: coordinator)
                .id(selection.id).environment(\.scenePhase, phase))
        }
        return AnyView(Color.clear)
    }

    private func synchronize() {
        syncBubble()
        guard !transitioning else { return }
        if let hosting, hosting.presentingViewController == nil, !hosting.isBeingPresented {
            self.hosting = nil; shownID = nil
        }
        if let hosting {
            guard !attached || desiredID != shownID else { return }
            transitioning = true
            hosting.dismiss(animated: attached) { [self] in
                self.hosting = nil; shownID = nil; transitioning = false
                synchronize()
            }
            return
        }
        guard attached, let desiredID, let coordinator else { return }
        guard phase == .active, let window = viewIfLoaded?.window ?? sceneWindow,
              let root = window.rootViewController else { return }
        sceneWindow = window
        var presenter = root
        while let next = presenter.presentedViewController { presenter = next }
        // 不与系统权限弹窗和已有页面的退出动画竞争。
        guard !presenter.isBeingDismissed, !presenter.isBeingPresented,
              presenter.transitionCoordinator == nil, !(presenter is UIAlertController) else {
            scheduleRetry(); return
        }
        let host = CallHostingController(rootView: content(coordinator))
        host.didDisappear = { [weak self] in self?.scheduleRetry() }
        host.modalPresentationStyle = .overFullScreen
        host.modalTransitionStyle = .crossDissolve
        host.isModalInPresentation = true
        hosting = host; shownID = desiredID; transitioning = true
        presenter.present(host, animated: true) { [self] in transitioning = false; synchronize() }
    }

    private func scheduleRetry() {
        guard retry == nil, attached else { return }
        let item = DispatchWorkItem { [weak self] in
            self?.retry = nil
            self?.synchronize()
        }
        retry = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    private func syncBubble() {
        guard attached, floating, let coordinator,
              let window = viewIfLoaded?.window ?? sceneWindow else {
            if let bubble {
                bubble.view.removeFromSuperview()
                self.bubble = nil
            }
            return
        }
        if let bubble {
            bubble.rootView = CallFloatingView(coordinator: coordinator)
            window.bringSubviewToFront(bubble.view)
            return
        }
        let host = UIHostingController(rootView: CallFloatingView(coordinator: coordinator))
        host.view.backgroundColor = .clear
        host.view.frame = CGRect(x: window.bounds.width - 184, y: window.safeAreaInsets.top + 80, width: 172, height: 78)
        host.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragBubble(_:))))
        // 窗口浮层不属于零尺寸锚点的视图树，不能声明为锚点的 child。
        // 由 bubble 持有宿主，恢复通话或卸载时移除视图并释放。
        window.addSubview(host.view)
        bubble = host; clampBubble()
    }

    @objc private func dragBubble(_ gesture: UIPanGestureRecognizer) {
        guard let view = bubble?.view, let window = view.superview else { return }
        let translation = gesture.translation(in: window)
        view.center = CGPoint(x: view.center.x + translation.x, y: view.center.y + translation.y)
        gesture.setTranslation(.zero, in: window)
        clampBubble()
    }

    private func clampBubble() {
        guard let view = bubble?.view, let window = view.superview else { return }
        let bounds = window.bounds.inset(by: window.safeAreaInsets).insetBy(dx: 8, dy: 8)
        view.frame.origin.x = max(bounds.minX, min(view.frame.minX, bounds.maxX - view.frame.width))
        view.frame.origin.y = max(bounds.minY, min(view.frame.minY, bounds.maxY - view.frame.height))
    }
}

/// 底层相机/文件弹层可能由其业务异步关闭，跟随 UIKit 真正消失重新核对呈现。
@MainActor private final class CallHostingController: UIHostingController<AnyView> {
    var didDisappear: (() -> Void)?
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        didDisappear?()
    }
}

private struct CallFloatingView: View {
    @ObservedObject var coordinator: CallCoordinator
    var body: some View {
        Button { coordinator.restore() } label: {
            HStack(spacing: 12) {
                Image(systemName: coordinator.session?.kind == .video ? "video.fill" : "phone.fill")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(coordinator.session?.title ?? "通话").font(.subheadline.weight(.semibold)).lineLimit(1)
                    if let started = coordinator.session?.connectedAt {
                        Text(started, style: .timer).font(.caption).monospacedDigit()
                    } else { Text("返回通话").font(.caption) }
                }
            }.padding(14).frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(.white).background(MessagingTheme.accent, in: RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
        }.buttonStyle(.plain).accessibilityLabel("返回当前通话")
    }
}
