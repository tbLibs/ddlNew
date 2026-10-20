import SwiftUI

extension View {
    /// 覆盖聊天但保留其画面，供库在下拉时逐渐露出；兼容 iOS 16。
    func chatPhotoBrowser(item: Binding<ChatPhotoBrowserRequest?>, context: ChatContext?,
                          allowSharing: Bool = true, includeCachedHistory: Bool = true) -> some View {
        background {
            ChatPhotoBrowserPresentation(item: item, chatContext: context,
                                         allowSharing: allowSharing, includeCachedHistory: includeCachedHistory)
                .frame(width: 0, height: 0)
        }
    }
}

private struct ChatPhotoBrowserPresentation: UIViewControllerRepresentable {
    @Binding var item: ChatPhotoBrowserRequest?
    @Environment(\.scenePhase) private var scenePhase
    let chatContext: ChatContext?
    let allowSharing: Bool
    let includeCachedHistory: Bool

    func makeUIViewController(context: Context) -> ChatPhotoBrowserPresentationController {
        ChatPhotoBrowserPresentationController()
    }

    func updateUIViewController(_ controller: ChatPhotoBrowserPresentationController, context: Context) {
        guard let item, let chatContext else { controller.setContent(identity: nil, makeContent: nil); return }
        controller.setContent(identity: .init(messageID: item.id, context: chatContext)) {
            ChatPhotoBrowserView(gallery: item, context: chatContext,
                                 allowSharing: allowSharing, includeCachedHistory: includeCachedHistory,
                                 scenePhase: scenePhase) {
                // 过期预览的关闭不能清掉随后打开的另一条。
                if self.item?.id == item.id { self.item = nil }
            }
        }
    }

    static func dismantleUIViewController(_ controller: ChatPhotoBrowserPresentationController, coordinator: ()) {
        controller.detach()
    }
}

/// 单一透明呈现层；不搜索全局窗口，不让库和 fullScreenCover 各自退出一次。
@MainActor final class ChatPhotoBrowserPresentationController: UIViewController {
    struct Identity: Equatable {
        let messageID: String
        let context: ChatContext
    }

    private var desiredIdentity: Identity?
    private var makeContent: (() -> ChatPhotoBrowserView)?
    private var shownIdentity: Identity?
    private var hosting: UIHostingController<ChatPhotoBrowserView>?
    private var isTransitioning = false
    private var isAttached = true

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        synchronize()
    }

    func setContent(identity: Identity?, makeContent: (() -> ChatPhotoBrowserView)?) {
        desiredIdentity = identity
        self.makeContent = makeContent
        // UIKit 新建的 Hosting 不继承父 SwiftUI 的场景环境；同一页也必须持续接收状态。
        // 保持根视图类型和身份不变，保留 StateObject、当前页和已下载内容。
        if let hosting, shownIdentity == identity, let makeContent {
            hosting.rootView = makeContent()
        }
        synchronize()
    }

    func detach() {
        isAttached = false
        desiredIdentity = nil
        makeContent = nil
        synchronize()
    }

    private func synchronize() {
        guard !isTransitioning else { return }
        if let hosting {
            guard !isAttached || shownIdentity != desiredIdentity else { return }
            isTransitioning = true
            // 淡出包含图片和库背景的同一容器，不再叠加系统向下滑出的黑色整页。
            hosting.dismiss(animated: isAttached) { [self] in
                self.hosting = nil
                self.shownIdentity = nil
                self.isTransitioning = false
                self.synchronize()
            }
        } else if isAttached, viewIfLoaded?.window != nil, presentedViewController == nil,
                  let desiredIdentity, let makeContent {
            let hosting = UIHostingController(rootView: makeContent())
            hosting.view.backgroundColor = .clear
            hosting.view.isOpaque = false
            hosting.modalPresentationStyle = .overFullScreen
            hosting.modalTransitionStyle = .crossDissolve
            hosting.modalPresentationCapturesStatusBarAppearance = true
            self.hosting = hosting
            shownIdentity = desiredIdentity
            isTransitioning = true
            present(hosting, animated: true) { [self] in
                self.isTransitioning = false
                self.synchronize()
            }
        }
    }
}
