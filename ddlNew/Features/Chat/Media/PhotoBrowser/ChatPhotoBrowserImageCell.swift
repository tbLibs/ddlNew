import UIKit
import Kingfisher
import JXPhotoBrowser

/// 缩放与拖拽交给库的 JXZoomImageCell，只适配已解包文件和 GIF 渲染。
final class ChatPhotoBrowserImageCell: JXZoomImageCell {
    static let cellIdentifier = "ChatPhotoBrowserImageCell"
    var onTap: (() -> Void)?
    private let animatedView = AnimatedImageView()
    private var requestKey: String?
    private var messageID: String?
    private var isActive = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        animatedView.translatesAutoresizingMaskIntoConstraints = false
        animatedView.contentMode = .scaleAspectFit
        // 透明 GIF 的后续帧不能透出底下用于缩放几何的首帧。
        animatedView.backgroundColor = .black
        animatedView.isUserInteractionEnabled = false
        imageView.addSubview(animatedView)
        NSLayoutConstraint.activate([
            animatedView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            animatedView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            animatedView.topAnchor.constraint(equalTo: imageView.topAnchor),
            animatedView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor)
        ])
        doubleTapZoomScale = 2.5
        scrollView.maximumZoomScale = 4
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(message: ChatMessageRecord, preview: ChatMediaPreviewStore?, isActive: Bool, isForeground: Bool) {
        if messageID != message.id { clear(); messageID = message.id }
        self.isActive = isActive
        animatedView.autoPlayAnimatedImage = isActive
        if isActive { animatedView.startAnimating() } else { animatedView.stopAnimating() }
        guard isForeground, preview?.isInvalidated != true else { clear(); return }
        let host = OSSConnectionBootstrap.shared.current?.getFileHost
        let file = preview?.file
        let url = file ?? RemoteAvatarURL.resolve(message.thumbnail, relativeTo: host)
        guard let url else { return }
        let key = message.id + "|" + url.absoluteString + (file == nil ? "|thumbnail" : "|original")
        guard requestKey != key else { return }
        animatedView.kf.cancelDownloadTask()
        requestKey = key
        var options = ChatPhotoBrowserImageProcessor.options
        if file == nil {
            options = [.processor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: 800, height: 800))),
                       .downloader(NetworkImageDownloader.downloader(for: host)), .backgroundDecode]
        }
        animatedView.kf.setImage(with: url, placeholder: animatedView.image, options: options) { [weak self, weak preview] result in
            guard let self, self.requestKey == key, preview?.isInvalidated != true else { return }
            switch result {
            case .success(let value):
                self.imageView.image = value.image.images?.first ?? value.image
                self.animatedView.autoPlayAnimatedImage = self.isActive
                if self.isActive { self.animatedView.startAnimating() } else { self.animatedView.stopAnimating() }
                self.setNeedsLayout()
            case .failure:
                if file != nil { preview?.errorMessage = "图片无法预览，请重试" }
            }
        }
    }

    override func handleSingleTap(_ gesture: UITapGestureRecognizer) { onTap?() }

    func clear() {
        requestKey = nil; messageID = nil
        animatedView.kf.cancelDownloadTask()
        animatedView.kf.setImage(with: nil as URL?)
        animatedView.stopAnimating(); animatedView.image = nil
        super.prepareForReuse()
    }

    override func prepareForReuse() { clear(); onTap = nil }
}
