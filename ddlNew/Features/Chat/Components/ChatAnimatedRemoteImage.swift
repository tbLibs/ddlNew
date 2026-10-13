//
//  ChatAnimatedRemoteImage.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import Kingfisher

/// 已有GIF和贴纸复用旧媒体解码，动画缓冲、前后台和减少动态效果独立于发送状态。
struct ChatAnimatedRemoteImage: View {
    let url: URL?
    let fileHost: URL?
    let size: CGSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = true

    /// 只有前台可见且允许动态效果时创建动画视图，其他状态显示受限尺寸静态首帧。
    var body: some View {
        Group {
            if isVisible && scenePhase == .active && !reduceMotion {
                KFAnimatedImage(url)
                    .setProcessor(LegacyRemoteImageProcessor())
                    .serialize(by: LegacyRemoteImageCacheSerializer())
                    .downloader(NetworkImageDownloader.downloader(for: fileHost))
                    .loadDiskFileSynchronously(false)
                    .cancelOnDisappear(true)
                    .purgeFramesOnBackground(true)
                    .configure { imageView in
                        // 不预解码整个GIF；按控件尺寸预缩放，仅预取三帧。
                        imageView.framePreloadCount = 3
                        imageView.needsPrescaling = true
                        imageView.contentMode = .scaleAspectFit
                        imageView.clipsToBounds = true
                    }
                    .placeholder { ProgressView().accessibilityLabel("正在加载图片") }
                    .onFailureView { Image(systemName: "photo").foregroundStyle(.secondary) }
            } else {
                KFImage(url)
                    .setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: size))
                    .serialize(by: LegacyRemoteImageCacheSerializer())
                    .downloader(NetworkImageDownloader.downloader(for: fileHost))
                    .loadDiskFileSynchronously(false)
                    .cancelOnDisappear(true)
                    .placeholder { ProgressView().accessibilityLabel("正在加载图片") }
                    .onFailureView { Image(systemName: "photo").foregroundStyle(.secondary) }
                    .resizable().scaledToFit()
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}
