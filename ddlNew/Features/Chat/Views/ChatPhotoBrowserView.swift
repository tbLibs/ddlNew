//
//  ChatPhotoBrowserView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/16.
//

import SwiftUI
import AVKit
import Photos
import UIAdapter

/// 黑底由库独占并随下拉淡出，SwiftUI 外层保持透明。
struct ChatPhotoBrowserView: View {
    let gallery: ChatPhotoBrowserRequest
    let context: ChatContext
    var allowSharing = true
    var includeCachedHistory = true
    @StateObject private var resources: ChatPhotoBrowserResources
    @StateObject private var playback: ChatPhotoBrowserPlayback
    @State private var items: [ChatMessageRecord]
    @State private var currentID: String
    @State private var controlsVisible = true
    @State private var isClosing = false
    @State private var retryRevision = 0
    @State private var isSaving = false
    @State private var saveFeedback: String?
    @State private var saveTask: Task<Void, Never>?
    @State private var shareRequest: ChatPhotoBrowserShareRequest?
    private let onClose: () -> Void
    // 必须从源 SwiftUI 场景传入，不能读取独立 UIHostingController 的默认 background。
    let scenePhase: ScenePhase

    /// 一次呈现持有一份浏览快照；当前页为独立可变状态，缓存补页不改变点击身份。
    init(gallery: ChatPhotoBrowserRequest, context: ChatContext, allowSharing: Bool = true, includeCachedHistory: Bool = true, scenePhase: ScenePhase, onClose: @escaping () -> Void) {
        let playback = ChatPhotoBrowserPlayback()
        _playback = StateObject(wrappedValue: playback)
        _resources = StateObject(wrappedValue: ChatPhotoBrowserResources(
            warmImage: ChatPhotoBrowserImageProcessor.prefetch,
            warmVideo: { [weak playback] file in
                playback?.prepare(file: file)
                return { [weak playback] in playback?.release(file: file) }
            }))
        self.gallery = gallery; self.context = context; self.onClose = onClose
        self.scenePhase = scenePhase
        self.allowSharing = allowSharing; self.includeCachedHistory = includeCachedHistory
        _items = State(initialValue: gallery.items)
        _currentID = State(initialValue: gallery.initialID)
    }

    private var currentMessage: ChatMessageRecord? { items.first { $0.id == currentID } }
    private var preview: ChatMediaPreviewStore { resources.current }
    private var loadKey: LoadKey { LoadKey(id: currentID, active: scenePhase == .active && !isClosing, retry: retryRevision) }

    var body: some View {
        ZStack(alignment: .top) {
            ChatPhotoBrowser(items: items, currentID: currentID, resources: resources, playback: playback,
                             isActive: scenePhase == .active, onSelect: select,
                             onTapImage: { controlsVisible.toggle() }, onClose: close)
                .ignoresSafeArea()
            previewStatus.frame(maxWidth: .infinity, maxHeight: .infinity)
            if controlsVisible { toolbar }
        }
        // 只覆盖预览子树，避免外观偏好向呈现容器传播并使聊天页切换颜色。
        .environment(\.colorScheme, .dark)
        .statusBarHidden(!controlsVisible)
        .accessibilityAction(.escape) { close() }
        .messagingFeedbackToast(preview.errorMessage ?? saveFeedback)
        // 呈现入口放在稳定的页面上，Menu 关闭或预览文件状态变化都不会移除它。
        .sheet(item: $shareRequest) { request in
            ChatPhotoBrowserShareSheet(file: request.file) { error in
                finishShare(requestID: request.id, error: error)
            }
        }
        .task(id: loadKey) { await loadCurrent() }
        .task { await loadCachedHistory() }
        .onChange(of: preview.isInvalidated) { invalidated in if invalidated { playback.stop(); shareRequest = nil } }
        .onChange(of: scenePhase) { phase in if phase != .active { playback.stop(); resources.close() } }
        .onReceive(ChatRuntime.shared.$revision) { _ in
            if !ChatRuntime.shared.isCurrent(context) { playback.stop(); resources.close(); close() }
        }
        .onReceive(ChatRuntime.shared.$closedConversationContext) { closed in
            if closed == context { playback.stop(); resources.close(); close() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            let began = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue == AVAudioSession.InterruptionType.began.rawValue
            if began { playback.player?.pause() }
        }
        .onDisappear { saveTask?.cancel(); playback.stop(); resources.close() }
    }

    /// 翻页先停播，保留仍在窗口内的图片与文件，滑动中不切回缩略图。
    private func select(_ id: String) {
        guard !isClosing, id != currentID else { return }
        let isVideo = items.first(where: { $0.id == id })?.type == 2
        playback.pause(releaseAudioSession: !isVideo)
        if scenePhase == .active { resources.prepare(items: items, currentID: id, context: context) }
        else { resources.close() }
        currentID = id; controlsVisible = true; saveFeedback = nil
    }

    /// 加载和失败反馈保留 SwiftUI 呈现，不触发浏览器整页重载。
    @ViewBuilder private var previewStatus: some View {
        if preview.loading {
            ProgressView().tint(.white).padding(20.zoom()).background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12.zoom()))
                .allowsHitTesting(false)
        } else if preview.errorMessage != nil {
            if !preview.isInvalidated, let message = currentMessage {
                Button { resources.retry(message, context: context); retryRevision += 1 } label: {
                    Label("重新加载", systemImage: "arrow.clockwise").padding(16.zoom())
                }.foregroundStyle(.white).background(.black.opacity(0.7), in: Capsule())
            } else {
                Image(systemName: "photo.badge.exclamationmark").font(.largeTitle).foregroundStyle(.white.opacity(0.6)).accessibilityLabel("原消息已失效")
                    .allowsHitTesting(false)
            }
        }
    }

    private func close() {
        guard !isClosing else { return }
        isClosing = true
        shareRequest = nil
        saveTask?.cancel(); playback.pause(releaseAudioSession: true)
        // 保留关闭动画中的最后画面，onDisappear 再释放资源。
        onClose()
    }

    /// 图片使用轻量悬浮操作，视频播放控制沿用系统播放器；没有常驻底部分享条。
    private var toolbar: some View {
        HStack {
            Spacer()
            if allowSharing, let file = preview.file, !preview.isInvalidated, let message = currentMessage {
                Menu {
                    Button { save(file, message: message) } label: { Label("保存到相册", systemImage: "square.and.arrow.down") }.disabled(isSaving)
                    Button { share(file, message: message) } label: { Label("分享", systemImage: "square.and.arrow.up") }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 22.zoom(), weight: .semibold)).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
                }.accessibilityLabel("更多操作")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12.zoom()).padding(.top, 4.zoom())
        .background(LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom).ignoresSafeArea(edges: .top))
    }

    private func share(_ file: URL, message: ChatMessageRecord) {
        guard allowSharing, !isClosing, shareRequest == nil, !preview.isInvalidated,
              currentID == message.id, preview.file == file, ChatRuntime.shared.isCurrent(context),
              !ChatRuntime.shared.isMessageDeleted(message, context: context) else { return }
        guard FileManager.default.fileExists(atPath: file.path) else {
            saveFeedback = "附件已不可用，请重新加载后分享"
            return
        }
        saveFeedback = nil
        shareRequest = ChatPhotoBrowserShareRequest(file: file)
    }

    private func finishShare(requestID: UUID, error: String?) {
        guard shareRequest?.id == requestID else { return }
        shareRequest = nil
        if !isClosing, ChatRuntime.shared.isCurrent(context) { saveFeedback = error }
    }

    /// 任务键绑定页码、前后台与重试；快速翻页时旧解包结果没有发布和播放资格。
    private func loadCurrent() async {
        guard !Task.isCancelled else { return }
        guard !isClosing, scenePhase == .active, let message = currentMessage, !Task.isCancelled,
              ChatRuntime.shared.isCurrent(context) else { return }
        resources.prepare(items: items, currentID: currentID, context: context)
        let preview = preview; let playback = playback
        ChatRuntime.shared.registerCleanup(owner: preview, conversationID: context.route.id) { [weak preview, weak playback] in
            playback?.stop(); preview?.close()
        }
        await resources.waitForLoad(message.id)
        guard !Task.isCancelled, !isClosing, currentID == message.id, scenePhase == .active,
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
            items = ChatPhotoBrowserRequest(selected: gallery.selected, messages: cached + gallery.items).items
            if scenePhase == .active { resources.prepare(items: items, currentID: currentID, context: context) }
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
