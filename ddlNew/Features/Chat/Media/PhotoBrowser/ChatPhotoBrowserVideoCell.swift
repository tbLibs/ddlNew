import SwiftUI
import AVKit
import Kingfisher
import JXPhotoBrowser

/// 使用库的自定义媒体 Cell 协议，视频内容和系统控制通过 SwiftUI 承载。
final class ChatPhotoBrowserVideoCell: UICollectionViewCell, JXPhotoBrowserCellProtocol {
    static let cellIdentifier = "ChatPhotoBrowserVideoCell"
    weak var browser: JXPhotoBrowserViewController?
    private let surface = UIImageView()
    private var hosting: UIHostingController<ChatPhotoBrowserVideoContent>?
    var transitionImageView: UIImageView? { surface }
    private var dismissClips: (Bool, Bool)?

    func photoBrowserDismissInteractionDidChange(isInteracting: Bool) {
        if isInteracting, dismissClips == nil {
            dismissClips = (clipsToBounds, contentView.clipsToBounds)
            clipsToBounds = false; contentView.clipsToBounds = false
        } else if !isInteracting, let saved = dismissClips {
            clipsToBounds = saved.0; contentView.clipsToBounds = saved.1
            dismissClips = nil
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        surface.isUserInteractionEnabled = true
        surface.backgroundColor = .black
        contentView.addSubview(surface)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 下拉手势会改变 transform，布局时更新 bounds/center，避免重写变换后的 frame。
        surface.bounds = CGRect(origin: .zero, size: contentView.bounds.size)
        surface.center = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
    }

    func configure(message: ChatMessageRecord, player: AVPlayer?, isActive: Bool, isHidden: Bool, browser: JXPhotoBrowserViewController) {
        let content = ChatPhotoBrowserVideoContent(message: message, player: isHidden ? nil : player,
                                                   isActive: isActive, isHidden: isHidden)
        if let hosting { hosting.rootView = content; return }
        let hosting = UIHostingController(rootView: content)
        self.hosting = hosting
        browser.addChild(hosting)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: surface.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: surface.bottomAnchor)
        ])
        hosting.didMove(toParent: browser)
    }

    func clear() {
        photoBrowserDismissInteractionDidChange(isInteracting: false)
        hosting?.willMove(toParent: nil)
        hosting?.view.removeFromSuperview()
        hosting?.removeFromParent()
        hosting = nil
        surface.transform = .identity
    }

    override func prepareForReuse() { super.prepareForReuse(); clear() }
}

private struct ChatPhotoBrowserVideoContent: View {
    let message: ChatMessageRecord
    let player: AVPlayer?
    let isActive: Bool
    let isHidden: Bool

    var body: some View {
        ZStack {
            Color.black
            if !isHidden {
                if let player {
                    ChatPhotoBrowserPlayerView(player: player, isActive: isActive) { cover }
                        .id(ObjectIdentifier(player))
                } else { cover }
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .accessibilityLabel("视频")
    }

    @ViewBuilder private var cover: some View {
        let host = OSSConnectionBootstrap.shared.current?.getFileHost
        if !message.thumbnail.isEmpty, let url = RemoteAvatarURL.resolve(message.thumbnail, relativeTo: host) {
            KFImage(url)
                .setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: 800, height: 800)))
                .downloader(NetworkImageDownloader.downloader(for: host))
                .cancelOnDisappear(true).resizable().scaledToFit()
                .accessibilityHidden(true)
        }
    }
}

/// 每页持有稳定的系统播放界面；准备完成前用封面遮住尚未出帧的黑色表面。
private struct ChatPhotoBrowserPlayerView<Cover: View>: View {
    let player: AVPlayer
    let isActive: Bool
    @ViewBuilder var cover: () -> Cover
    @State private var readyForDisplay = false

    var body: some View {
        ZStack {
            ChatPhotoBrowserPlayerSurface(player: player, isActive: isActive, readyForDisplay: $readyForDisplay)
            if !readyForDisplay {
                Color.black
                cover().allowsHitTesting(false)
            }
        }
    }
}

private struct ChatPhotoBrowserPlayerSurface: UIViewControllerRepresentable {
    let player: AVPlayer
    let isActive: Bool
    @Binding var readyForDisplay: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = isActive
        controller.allowsPictureInPicturePlayback = false
        controller.view.backgroundColor = .black
        let coordinator = context.coordinator
        let ready = $readyForDisplay
        coordinator.observation = controller.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak coordinator, weak controller] _, _ in
            Task { @MainActor [weak coordinator, weak controller] in
                guard let coordinator, coordinator.isAttached, let controller else { return }
                if ready.wrappedValue != controller.isReadyForDisplay { ready.wrappedValue = controller.isReadyForDisplay }
            }
        }
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.showsPlaybackControls = isActive
        controller.view.isUserInteractionEnabled = isActive
    }

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.isAttached = false
        coordinator.observation?.invalidate()
        coordinator.observation = nil
        // 只解除该页面的挂载，暂停/释放由三页窗口统一管理。
        controller.player = nil
    }

    @MainActor final class Coordinator {
        var isAttached = true
        var observation: NSKeyValueObservation?
    }
}
