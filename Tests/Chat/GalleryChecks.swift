import Foundation

enum GalleryScenePhase { case active, inactive }
@MainActor final class GalleryPreviewBoundary {
    var file: URL?
    var isInvalidated = false
    var errorMessage: String?
    var pending: [String: CheckedContinuation<Void, Never>] = [:]
    var closes = 0
    func close() { closes += 1; file = nil }
    func load(_ message: ChatMessageRecord, context: ChatContext) async {
        await withCheckedContinuation { pending[message.id] = $0 }
        // 故意允许旧下载回调完成，生产页面仍须阻止其开始播放。
        file = URL(fileURLWithPath: "/tmp/\(message.id).mp4")
    }
    func waitForPending(_ id: String) async {
        let deadline = Date().addingTimeInterval(5)
        while pending[id] == nil && Date() < deadline { await Task.yield() }
        if pending[id] == nil { print("FAIL 下载任务未在截止前进入等待"); exit(1) }
    }
    func finish(_ id: String) { pending.removeValue(forKey: id)?.resume() }
}
@MainActor final class GalleryPlaybackBoundary {
    var file: URL?
    var stops = 0
    func stop() { stops += 1; file = nil }
    func play(file: URL, onFailure: @escaping @MainActor () -> Void) throws { self.file = file }
}
@MainActor final class ChatRuntime {
    static let shared = ChatRuntime()
    var valid = true
    var cleanup: (() -> Void)?
    func isCurrent(_ context: ChatContext) -> Bool { valid }
    func registerCleanup(owner: AnyObject, conversationID: String?, action: @escaping @MainActor () -> Void) { cleanup = action }
}

@main struct GalleryChecks {
    @MainActor static func main() async {
        var failures = 0
        func check(_ passed: Bool, _ title: String) {
            print("\(passed ? "PASS" : "FAIL") \(title)")
            if !passed { failures += 1 }
        }
        func message(_ id: String, type: Int = 1, time: Int64 = 10, conversation: String = "chat") -> ChatMessageRecord {
            var value = ChatMessageRecord(localID: id, conversationID: conversation, senderID: "sender", senderName: "", type: type, timestamp: time)
            value.resource = "/media/\(id)"; value.state = .sent
            return value
        }
        let photo = message("photo", time: 20)
        let video = message("video", type: 2, time: 30)
        let route = GalleryRouteHarness()
        route.store.messages = [video, photo, message("text", type: 0)]
        route.open(photo)
        check(route.mediaGallery?.initialID == "photo" && route.mediaMessage == nil, "图片打开全屏画廊而非文件详情")
        route.mediaGallery = nil
        route.open(video)
        check(route.mediaGallery?.initialID == "video", "视频直接定位所点页")
        route.mediaGallery = nil
        route.open(message("file", type: 5))
        check(route.mediaMessage?.id == "file" && route.mediaGallery == nil, "文件继续原下载预览入口")
        route.composerMode.panel = .selection
        route.open(photo)
        check(route.store.toggledID == "photo" && route.mediaGallery == nil, "多选时点击媒体只切换选择")
        route.composerMode.panel = .keyboard
        var uploading = photo; uploading.isMediaUploading = true
        route.open(uploading)
        check(route.mediaGallery == nil, "上传占位不能提前打开远端预览")

        var recalled = message("recalled"); recalled.status = .recalled
        var deleted = message("deleted"); deleted.status = .deleted
        var incompatible = message("unsupported"); incompatible.isCompatible = false
        var empty = message("empty"); empty.resource = " "
        let gallery = ChatMediaGallery(selected: photo, messages: [video, recalled, deleted, incompatible, empty, uploading,
            message("other", conversation: "other-chat"), message("voice", type: 4), message("sticker", type: 12), photo, photo])
        check(gallery.items.map(\.id) == ["photo", "video"], "混合媒体按时间去重并隔离其他会话及失效资源")
        let missing = ChatMediaGallery(selected: photo, messages: [video])
        check(missing.items.map(\.id) == ["photo", "video"] && missing.initialID == "photo", "历史快照暂缺点击条仍保留选中身份")
        let sticker = message("sticker", type: 12)
        let stickerGallery = ChatMediaGallery(selected: sticker, messages: [photo, video, sticker])
        check(stickerGallery.items.map(\.id) == ["sticker"], "独立贴纸预览不混入会话图片视频")
        let invalid = ChatMediaGallery(selected: recalled, messages: [recalled])
        check(invalid.items.isEmpty, "撤回条不能重新进入画廊")
        check(!ChatMediaGallery.shouldDismiss(translation: CGSize(width: 200, height: 100), zoomScale: 1)
            && ChatMediaGallery.shouldDismiss(translation: CGSize(width: 10, height: 130), zoomScale: 1)
            && !ChatMediaGallery.shouldDismiss(translation: CGSize(width: 0, height: 150), zoomScale: 2), "左右翻页与放大拖动不能误触关闭")
        let context = ChatContext(userUID: "qa", tenantID: "tenant", sessionID: UUID(), route: ChatRoute(id: "chat", kind: .single, title: "", avatarURL: ""))
        let lifecycle = GalleryLifecycleHarness(context: context, items: [video, photo])
        let firstLoad = Task { await lifecycle.load() }
        await lifecycle.preview.waitForPending("video")
        lifecycle.preview.finish("video"); await firstLoad.value
        check(lifecycle.playback.file?.lastPathComponent == "video.mp4", "当前视频下载结束自动播放本页文件")
        let stopsBeforeCancelledStart = lifecycle.playback.stops
        let cancelledBeforeStart = Task { await lifecycle.load() }
        cancelledBeforeStart.cancel(); await cancelledBeforeStart.value
        check(lifecycle.playback.stops == stopsBeforeCancelledStart && lifecycle.playback.file?.lastPathComponent == "video.mp4", "尚未开始即被取消的旧任务不能关闭当前正在播放的新页")
        lifecycle.choose("photo")
        check(lifecycle.playback.file == nil && lifecycle.preview.file == nil && lifecycle.currentID == "photo", "翻页先停播和取消旧附件再切换身份")
        lifecycle.choose("video")
        let staleLoad = Task { await lifecycle.load() }
        await lifecycle.preview.waitForPending("video")
        lifecycle.choose("photo"); lifecycle.preview.finish("video"); await staleLoad.value
        check(lifecycle.playback.file == nil, "快速翻页后的迟到视频不能开始播放")
        lifecycle.choose("video")
        let cancelled = Task { await lifecycle.load() }
        await lifecycle.preview.waitForPending("video")
        cancelled.cancel(); lifecycle.preview.finish("video"); await cancelled.value
        check(lifecycle.playback.file == nil, "任务取消后同一视频的迟到结果不能开始播放")
        lifecycle.scenePhase = .inactive
        await lifecycle.load()
        check(lifecycle.preview.pending.isEmpty && lifecycle.playback.file == nil, "非前台不下载也不自动播放")
        lifecycle.scenePhase = .active
        let closing = Task { await lifecycle.load() }
        await lifecycle.preview.waitForPending("video")
        ChatRuntime.shared.valid = false; ChatRuntime.shared.cleanup?()
        lifecycle.preview.finish("video"); await closing.value
        check(lifecycle.playback.file == nil, "AUTH 退出的清理停止播放器且迟到结果不能重播")
        print("Gallery checks: \(17 - failures)/17")
        if failures > 0 { exit(1) }
    }
}
