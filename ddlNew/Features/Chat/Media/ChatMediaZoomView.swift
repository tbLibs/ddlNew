//
//  ChatMediaZoomView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/16.
//

import SwiftUI
import Kingfisher

/// TabView 负责横向翻页，UIScrollView 提供 iOS 16 的捏合、双击及放大后平移。
struct ChatMediaZoomView: UIViewRepresentable {
    let file: URL
    let onScaleChanged: (CGFloat) -> Void
    let onTap: () -> Void
    let onFailure: () -> Void

    /// 本地文件已由预览 Store 解包，图片层不再发起远端下载。
    func makeUIView(context: Context) -> ChatMediaZoomScrollView {
        let scroll = ChatMediaZoomScrollView()
        scroll.delegate = context.coordinator
        let single = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.singleTap))
        let double = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        double.numberOfTapsRequired = 2
        single.require(toFail: double)
        scroll.addGestureRecognizer(single); scroll.addGestureRecognizer(double)
        return scroll
    }

    /// 相同文件不重复解码，页面销毁或原条失效后由 SwiftUI 移除图片层。
    func updateUIView(_ scroll: ChatMediaZoomScrollView, context: Context) {
        context.coordinator.parent = self
        guard scroll.file != file else { return }
        scroll.file = file
        scroll.setZoomScale(1, animated: false)
        scroll.imageView.kf.setImage(with: file) { result in
            if case .failure = result, scroll.file == file { onFailure() }
        }
    }

    /// 离屏停止动图并撤销本地解码任务，避免画廊驻留图片继续动画。
    static func dismantleUIView(_ scroll: ChatMediaZoomScrollView, coordinator: Coordinator) {
        scroll.file = nil; scroll.imageView.kf.cancelDownloadTask()
        scroll.imageView.stopAnimating(); scroll.imageView.image = nil
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ChatMediaZoomView
        init(_ parent: ChatMediaZoomView) { self.parent = parent }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { (scrollView as? ChatMediaZoomScrollView)?.imageView }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let scroll = scrollView as? ChatMediaZoomScrollView else { return }
            scroll.imageView.center = CGPoint(x: max(scroll.contentSize.width, scroll.bounds.width) / 2,
                                              y: max(scroll.contentSize.height, scroll.bounds.height) / 2)
            parent.onScaleChanged(scroll.zoomScale)
        }
        @objc func singleTap() { parent.onTap() }
        /// 双击回到适应屏幕或以点击位置放大，手势与系统捏合共用同一缩放值。
        @objc func doubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scroll = gesture.view as? ChatMediaZoomScrollView else { return }
            if scroll.zoomScale > 1.01 { scroll.setZoomScale(1, animated: true) }
            else {
                let point = gesture.location(in: scroll.imageView)
                let size = CGSize(width: scroll.bounds.width / 2.5, height: scroll.bounds.height / 2.5)
                scroll.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: true)
            }
        }
    }
}

final class ChatMediaZoomScrollView: UIScrollView {
    let imageView = AnimatedImageView()
    var file: URL?
    private var viewportSize = CGSize.zero

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear; minimumZoomScale = 1; maximumZoomScale = 6
        showsVerticalScrollIndicator = false; showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        imageView.contentMode = .scaleAspectFit
        imageView.accessibilityLabel = "图片"
        imageView.isAccessibilityElement = true
        addSubview(imageView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 未放大时把平移手势交给外层分页和下滑关闭，捏合与双击仍由图片响应。
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer, zoomScale <= 1.01 { return false }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    /// 旋转或 iPad 尺寸变化后重新适应实际视口，避免沿用旧屏幕的放大偏移。
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != viewportSize, bounds.width > 0, bounds.height > 0 else { return }
        viewportSize = bounds.size
        setZoomScale(1, animated: false)
        imageView.frame = CGRect(origin: .zero, size: bounds.size)
        contentSize = bounds.size
    }
}
