//
//  ChatMediaGalleryView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/16.
//

import SwiftUI
import AVKit
import Photos
import Kingfisher
import UIAdapter

/// 图片视频共用黑底全屏分页，下载解包和消息失效仍由现有预览 Store 负责。
struct ChatMediaGalleryView: View {
    let gallery: ChatMediaGallery
    let context: ChatContext
    var allowSharing = true
    var includeCachedHistory = true
    @StateObject private var preview = ChatRuntime.shared.makePreviewStore()
    @StateObject private var playback = ChatMediaGalleryPlayback()
    @State private var items: [ChatMessageRecord]
    @State private var currentID: String
    @State private var zoomScale: CGFloat = 1
    @State private var controlsVisible = true
    @State private var retryRevision = 0
    @State private var isSaving = false
    @State private var saveFeedback: String?
    @State private var saveTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// 一次呈现持有一份浏览快照；当前页为独立可变状态，缓存补页不改变点击身份。
    init(gallery: ChatMediaGallery, context: ChatContext, allowSharing: Bool = true, includeCachedHistory: Bool = true) {
        self.gallery = gallery; self.context = context
        self.allowSharing = allowSharing; self.includeCachedHistory = includeCachedHistory
        _items = State(initialValue: gallery.items)
        _currentID = State(initialValue: gallery.initialID)
    }

    private var currentMessage: ChatMessageRecord? { items.first { $0.id == currentID } }
    private var loadKey: LoadKey { LoadKey(id: currentID, active: scenePhase == .active, retry: retryRevision) }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            TabView(selection: Binding(get: { currentID }, set: select)) {
                ForEach(items) { message in
                    mediaPage(message)
                        .tag(message.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .simultaneousGesture(DragGesture().onEnded { value in
                if ChatMediaGallery.shouldDismiss(translation: value.translation, zoomScale: zoomScale) { dismiss() }
            })
            if controlsVisible { toolbar }
        }
        .background(.black)
        .preferredColorScheme(.dark)
        .statusBarHidden(!controlsVisible)
        .accessibilityAction(.escape) { dismiss() }
        .messagingFeedbackToast(preview.errorMessage ?? saveFeedback)
        .task(id: loadKey) { await loadCurrent() }
        .task { await loadCachedHistory() }
        .onChange(of: preview.isInvalidated) { invalidated in if invalidated { playback.stop() } }
        .onChange(of: scenePhase) { phase in if phase != .active { playback.stop(); preview.close() } }
        .onReceive(ChatRuntime.shared.$revision) { _ in
            if !ChatRuntime.shared.isCurrent(context) { playback.stop(); preview.close(); dismiss() }
        }
        .onReceive(ChatRuntime.shared.$closedConversationContext) { closed in
            if closed == context { playback.stop(); preview.close(); dismiss() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            let began = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue == AVAudioSession.InterruptionType.began.rawValue
            if began { playback.player?.pause() }
        }
        .onDisappear { saveTask?.cancel(); playback.stop(); preview.close() }
    }

    /// 在翻页绑定写入前停播和取消旧下载，避免 onChange 与新页缓存命中互相覆盖。
    private func select(_ id: String) {
        guard id != currentID else { return }
        playback.stop(); preview.close()
        currentID = id; zoomScale = 1; controlsVisible = true; saveFeedback = nil
    }

    /// 仅当前页挂载解码图片或播放器，TabView 预建邻页时不播放、不下载原文件。
    @ViewBuilder private func mediaPage(_ message: ChatMessageRecord) -> some View {
        ZStack {
            Color.black
            if message.id == currentID, let file = preview.file, !preview.isInvalidated {
                if message.type == 2, let player = playback.player {
                    VideoPlayer(player: player).accessibilityLabel("视频播放器")
                } else if message.type != 2 {
                    ChatMediaZoomView(file: file, onScaleChanged: { scale in
                        if abs(zoomScale - scale) > 0.01 { zoomScale = scale }
                    }, onTap: { controlsVisible.toggle() }, onFailure: {
                        preview.errorMessage = "图片无法预览，请重试"
                    })
                }
            } else {
                placeholder(message)
            }
            if message.id == currentID {
                if preview.loading {
                    ProgressView().tint(.white).padding(20.zoom()).background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12.zoom()))
                } else if preview.errorMessage != nil {
                    if !preview.isInvalidated {
                        Button { retryRevision += 1 } label: { Label("重新加载", systemImage: "arrow.clockwise").padding(16.zoom()) }
                            .foregroundStyle(.white).background(.black.opacity(0.7), in: Capsule())
                    } else {
                        Image(systemName: "photo.badge.exclamationmark").font(.largeTitle).foregroundStyle(.white.opacity(0.6)).accessibilityLabel("原消息已失效")
                    }
                }
            }
        }
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message.type == 2 ? "视频" : "图片")
    }

    /// 封面继续共用旧媒体处理器和文件 Host 策略；原条失效后不再展示旧封面。
    @ViewBuilder private func placeholder(_ message: ChatMessageRecord) -> some View {
        if message.id != currentID || !preview.isInvalidated {
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

    /// 图片使用轻量悬浮操作，视频播放控制沿用系统播放器；没有常驻底部分享条。
    private var toolbar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down").font(.system(size: 20.zoom(), weight: .semibold)).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
            }.accessibilityLabel("关闭预览")
            Spacer()
            if allowSharing, let file = preview.file, !preview.isInvalidated, let message = currentMessage {
                Menu {
                    Button { save(file, message: message) } label: { Label("保存到相册", systemImage: "square.and.arrow.down") }.disabled(isSaving)
                    ShareLink(item: file) { Label("分享", systemImage: "square.and.arrow.up") }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 22.zoom(), weight: .semibold)).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
                }.accessibilityLabel("更多操作")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12.zoom()).padding(.top, 4.zoom())
        .background(LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom).ignoresSafeArea(edges: .top))
    }

    /// 任务键绑定页码、前后台与重试；快速翻页时旧解包结果没有发布和播放资格。
    private func loadCurrent() async {
        guard !Task.isCancelled else { return }
        playback.stop(); preview.close()
        guard scenePhase == .active, let message = currentMessage, !Task.isCancelled,
              ChatRuntime.shared.isCurrent(context) else { return }
        let preview = preview; let playback = playback
        ChatRuntime.shared.registerCleanup(owner: preview, conversationID: context.route.id) { [weak preview, weak playback] in
            playback?.stop(); preview?.close()
        }
        await preview.load(message, context: context)
        guard !Task.isCancelled, currentID == message.id, scenePhase == .active,
              ChatRuntime.shared.isCurrent(context), !preview.isInvalidated, let file = preview.file, message.type == 2 else { return }
        do {
            try playback.play(file: file) { [weak preview] in preview?.errorMessage = "视频无法播放，请重试" }
        } catch { preview.errorMessage = "视频无法播放，请重试" }
    }

    /// 与旧端一样补齐本机缓存中的图片视频，复用现有 SDK 分类查询，不拉取远端历史。
    private func loadCachedHistory() async {
        guard includeCachedHistory, gallery.selected.type != 12 else { return }
        let contentRevision = ChatRuntime.shared.contentRevision(context)
        let client = SDKChatHistorySearchClient()
        var cached: [ChatMessageRecord] = []
        var offset = 0
        do {
            while !Task.isCancelled {
                let page = try await client.search(context: context, category: .media, keyword: "", memberIDs: [], offset: offset)
                guard !Task.isCancelled, ChatRuntime.shared.isCurrent(context),
                      ChatRuntime.shared.contentRevision(context) == contentRevision else { return }
                cached += page.messages
                if !page.hasMore || page.nextOffset <= offset { break }
                offset = page.nextOffset
            }
            guard !Task.isCancelled else { return }
            items = ChatMediaGallery(selected: gallery.selected, messages: cached + gallery.items).items
        } catch {
            // 缓存补页失败仍可浏览已经打开的记录，下载失败由当前页单独反馈。
        }
    }

    /// 保存只申请添加权限，授权等待后复核身份和当前原条，再交给 Photos 写入。
    private func save(_ file: URL, message: ChatMessageRecord) {
        guard !isSaving, !preview.isInvalidated else { return }
        isSaving = true; saveFeedback = nil
        saveTask = Task { @MainActor in
            defer { isSaving = false }
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard !Task.isCancelled, ChatRuntime.shared.isCurrent(context), currentID == message.id,
                  !preview.isInvalidated, !ChatRuntime.shared.isMessageDeleted(message, context: context),
                  FileManager.default.fileExists(atPath: file.path) else { return }
            guard status == .authorized || status == .limited else { saveFeedback = "请在系统设置中允许添加照片"; return }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    if message.type == 2 { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: file) }
                    else { PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: file) }
                }
                if !Task.isCancelled, ChatRuntime.shared.isCurrent(context) { saveFeedback = "已保存到相册" }
            } catch {
                if !Task.isCancelled, ChatRuntime.shared.isCurrent(context) { saveFeedback = "保存失败，请重试" }
            }
        }
    }

    private struct LoadKey: Equatable { let id: String; let active: Bool; let retry: Int }
}
