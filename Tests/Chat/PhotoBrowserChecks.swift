import Foundation
import Combine

enum GalleryScenePhase { case active, inactive }
typealias ChatMediaPreviewStore = GalleryPreviewBoundary
@MainActor final class GalleryPreviewBoundary: ObservableObject {
    @Published var file: URL?
    var isInvalidated = false
    var errorMessage: String?
    var pending: [String: CheckedContinuation<Void, Never>] = [:]
    var closes = 0
    var loadCount = 0
    func close() { closes += 1; file = nil }
    func load(_ message: ChatMessageRecord, context: ChatContext) async {
        loadCount += 1
        if message.type == 2 { await withCheckedContinuation { pending[message.id] = $0 } }
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
    func pause(releaseAudioSession: Bool = false) { file = nil }
    func play(file: URL, onFailure: @escaping @MainActor () -> Void) throws { self.file = file }
}
@MainActor final class ChatRuntime {
    static let shared = ChatRuntime()
    var valid = true
    var deleted = false
    func isMessageDeleted(_ message: ChatMessageRecord, context: ChatContext) -> Bool { deleted }
    var cleanups: [ObjectIdentifier: @MainActor () -> Void] = [:]
    var cleanup: (() -> Void)? { { for action in Array(self.cleanups.values) { action() } } }
    func makePreviewStore() -> GalleryPreviewBoundary { GalleryPreviewBoundary() }
    func isCurrent(_ context: ChatContext) -> Bool { valid }
    func registerCleanup(owner: AnyObject, conversationID: String?, action: @escaping @MainActor () -> Void) { cleanups[ObjectIdentifier(owner)] = action }
}

@main struct GalleryChecks {
    @MainActor static func main() async {
        var failures = 0
        var checks = 0
        func check(_ passed: Bool, _ title: String) {
            checks += 1
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
        route.mediaMessage = nil
        route.open(message("inline-voice", type: 4))
        check(route.voicePlayback.openedID == "inline-voice" && route.mediaMessage == nil, "语音直接在聊天播放，不打开附件详情")
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
        let gallery = ChatPhotoBrowserRequest(selected: photo, messages: [video, recalled, deleted, incompatible, empty, uploading,
            message("other", conversation: "other-chat"), message("voice", type: 4), message("sticker", type: 12), photo, photo])
        check(gallery.items.map(\.id) == ["photo", "video"], "混合媒体按时间去重并隔离其他会话及失效资源")
        let missing = ChatPhotoBrowserRequest(selected: photo, messages: [video])
        check(missing.items.map(\.id) == ["photo", "video"] && missing.initialID == "photo", "历史快照暂缺点击条仍保留选中身份")
        let sticker = message("sticker", type: 12)
        let stickerGallery = ChatPhotoBrowserRequest(selected: sticker, messages: [photo, video, sticker])
        check(stickerGallery.items.map(\.id) == ["sticker"], "独立贴纸预览不混入会话图片视频")
        let invalid = ChatPhotoBrowserRequest(selected: recalled, messages: [recalled])
        check(invalid.items.isEmpty, "撤回条不能重新进入画廊")
        var selection = ChatPhotoBrowserSelection(ids: ["photo", "video"], selectedID: "video")
        check(selection.index == 1, "SwiftUI桥接定位点击的视频页")
        selection.replace(["older", "photo", "video"])
        check(selection.selectedID == "video" && selection.index == 2, "浏览器补历史后按消息身份保留当前视频")
        check(selection.select(index: 2) == nil && selection.select(index: -1) == nil && selection.select(index: 99) == nil,
              "框架重复页码与过期越界通知不重复发起加载")
        check(selection.select(index: 1) == "photo", "浏览器有效翻页回写对应消息身份")
        selection.replace([])
        check(selection.index == 0 && selection.selectedID.isEmpty, "空浏览快照安全清理选择")
        let bridge = GalleryBrowserSelectionHarness()
        bridge.didSelect(1); bridge.didSelect(2)
        check(bridge.parent.calls.isEmpty, "框架同步回调不在SwiftUI更新过程中立即改状态")
        let bridgeDeadline = Date().addingTimeInterval(3)
        while bridge.parent.calls.isEmpty && Date() < bridgeDeadline { await Task.yield() }
        check(bridge.parent.calls == ["three"], "快速连续翻页只发布最新消息身份")
        bridge.isReloading = true
        bridge.didSelect(0)
        check(bridge.selection.selectedID == "three", "框架重载中间页码不能覆盖当前消息身份")
        bridge.isReloading = false
        bridge.didSelect(0)
        bridge.isAttached = false
        for _ in 0..<20 { await Task.yield() }
        check(bridge.parent.calls == ["three"], "SwiftUI卸载后已排队的翻页回调不能重新加载媒体")
        let context = ChatContext(userUID: "qa", tenantID: "tenant", sessionID: UUID(), route: ChatRoute(id: "chat", kind: .single, title: "", avatarURL: ""))
        let sharing = GalleryLifecycleHarness(context: context, items: [photo])
        let sharedFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        try? Data([1, 2, 3]).write(to: sharedFile)
        defer { try? FileManager.default.removeItem(at: sharedFile) }
        sharing.preview.file = sharedFile
        sharing.shareFile(sharedFile, message: photo)
        check(sharing.shareRequest?.file == sharedFile, "分享按钮生成当前图片文件快照，供页面级面板呈现")
        let shareID = sharing.shareRequest!.id
        sharing.shareFile(sharedFile, message: photo)
        check(sharing.shareRequest?.id == shareID, "重复点击分享不叠加面板")
        sharing.preview.close()
        check(sharing.shareRequest?.file == sharedFile, "菜单退出或预览状态清理不丢失分享文件快照")
        sharing.finishSharing(UUID(), error: "旧回调")
        check(sharing.shareRequest?.id == shareID, "过期分享回调不能关闭当前面板")
        sharing.finishSharing(shareID, error: nil)
        check(sharing.shareRequest == nil && sharing.saveFeedback == nil, "取消或完成分享后清理请求且不误报失败")
        sharing.preview.file = sharedFile
        sharing.shareFile(sharedFile, message: photo)
        sharing.finishSharing(sharing.shareRequest!.id, error: "分享失败，请重试")
        check(sharing.shareRequest == nil && sharing.saveFeedback == "分享失败，请重试", "系统分享失败返回可见反馈")
        sharing.allowSharing = false
        sharing.shareFile(sharedFile, message: photo)
        check(sharing.shareRequest == nil, "合并记录禁分享规则保持")
        sharing.allowSharing = true
        ChatRuntime.shared.deleted = true
        sharing.shareFile(sharedFile, message: photo)
        check(sharing.shareRequest == nil, "已撤回删除的图片不能发起分享")
        ChatRuntime.shared.deleted = false
        sharing.shareFile(sharedFile, message: video)
        check(sharing.shareRequest == nil, "过期菜单不能分享其他消息的文件")
        try? FileManager.default.removeItem(at: sharedFile)
        sharing.shareFile(sharedFile, message: photo)
        check(sharing.shareRequest == nil && sharing.saveFeedback == "附件已不可用，请重新加载后分享", "缓存文件丢失时提示用户而非点击无反馈")
        let lifecycle = GalleryLifecycleHarness(context: context, items: [video, photo])
        let firstLoad = Task { await lifecycle.load() }
        while lifecycle.resources.previews["video"] == nil { await Task.yield() }
        await lifecycle.preview.waitForPending("video")
        lifecycle.preview.finish("video"); await firstLoad.value
        check(lifecycle.playback.file?.lastPathComponent == "video.mp4", "当前视频下载结束自动播放本页文件")
        let stopsBeforeCancelledStart = lifecycle.playback.stops
        let cancelledBeforeStart = Task { await lifecycle.load() }
        cancelledBeforeStart.cancel(); await cancelledBeforeStart.value
        check(lifecycle.playback.stops == stopsBeforeCancelledStart && lifecycle.playback.file?.lastPathComponent == "video.mp4", "尚未开始即被取消的旧任务不能关闭当前正在播放的新页")
        let previousPreview = lifecycle.preview
        lifecycle.choose("photo")
        check(lifecycle.playback.file == nil && previousPreview.file != nil && lifecycle.currentID == "photo", "翻页立即停播但保留仍在相邻范围的文件，避免滑动中途退回占位图")
        let preparedPhoto = lifecycle.preview
        await lifecycle.load()
        check(preparedPhoto.file != nil && preparedPhoto.loadCount == 1, "邻页提前加载，选中时不重复下载")
        lifecycle.choose("video")
        await lifecycle.load()
        check(lifecycle.preview === previousPreview && previousPreview.loadCount == 1, "往返邻页复用原Store和文件")

        let stale = GalleryLifecycleHarness(context: context, items: [video, photo])
        let staleLoad = Task { await stale.load() }
        let stalePreview: GalleryPreviewBoundary
        while stale.resources.previews["video"] == nil { await Task.yield() }
        stalePreview = stale.resources.previews["video"]!
        await stalePreview.waitForPending("video")
        stale.choose("photo"); stalePreview.finish("video"); await staleLoad.value
        check(stale.playback.file == nil, "快速翻页后的迟到视频不能开始播放")

        let cancelPage = GalleryLifecycleHarness(context: context, items: [video, photo])
        let cancelled = Task { await cancelPage.load() }
        while cancelPage.resources.previews["video"] == nil { await Task.yield() }
        let cancelledPreview = cancelPage.resources.previews["video"]!
        await cancelledPreview.waitForPending("video")
        cancelled.cancel(); cancelledPreview.finish("video"); await cancelled.value
        check(cancelPage.playback.file == nil, "任务取消后同一视频的迟到结果不能开始播放")

        let dismissing = GalleryLifecycleHarness(context: context, items: [video, photo])
        let dismissingLoad = Task { await dismissing.load() }
        while dismissing.resources.previews["video"] == nil { await Task.yield() }
        let dismissingPreview = dismissing.resources.previews["video"]!
        await dismissingPreview.waitForPending("video")
        dismissing.isClosing = true
        dismissingPreview.finish("video"); await dismissingLoad.value
        dismissing.choose("photo")
        check(dismissing.playback.file == nil && dismissing.currentID == video.id,
              "关闭动画期间下载或翻页迟到不能重播或切换媒体")
        dismissing.resources.close()

        let inactive = GalleryLifecycleHarness(context: context, items: [video, photo])
        inactive.scenePhase = .inactive
        await inactive.load()
        check(inactive.resources.previews.isEmpty && inactive.playback.file == nil, "非前台不下载也不自动播放")
        inactive.choose("photo")
        check(inactive.resources.previews.isEmpty, "进入后台时迟到的翻页回调不能重新启动邻页下载")

        let images = [message("one"), message("two"), message("three"), message("four"), message("five")]
        let window = ChatPhotoBrowserResources(warmImage: { _ in {} })
        window.prepare(items: images, currentID: "three", context: context)
        await window.waitForLoad("two"); await window.waitForLoad("four")
        check(Set(window.previews.keys) == ["two", "three", "four"] && window.previews["two"]?.file != nil && window.previews["four"]?.file != nil,
              "未开始滑动前左右两张原图已加载且只保留三页")
        let outgoing = window.previews["two"]!
        let incoming = window.previews["four"]!
        window.prepare(items: images, currentID: "four", context: context)
        check(window.current === incoming && outgoing.file == nil && Set(window.previews.keys) == ["three", "four", "five"], "滑动复用已准备页并释放窗口外资源")
        window.close()
        check(window.previews.isEmpty && incoming.file == nil, "关闭预览释放所有邻页")
        var warmedVideos: [URL] = []
        var releasedVideos: [URL] = []
        let withVideo = ChatPhotoBrowserResources(warmImage: { _ in {} }, warmVideo: { file in
            warmedVideos.append(file)
            return { releasedVideos.append(file) }
        })
        withVideo.prepare(items: [photo, video], currentID: photo.id, context: context)
        await withVideo.waitForLoad(photo.id)
        await withVideo.previews[video.id]?.waitForPending(video.id)
        check(withVideo.previews[video.id]?.loadCount == 1, "邻页视频提前下载解包")
        withVideo.previews[video.id]?.finish(video.id)
        await withVideo.waitForLoad(video.id)
        check(warmedVideos.count == 1, "邻页视频解包后提前准备播放器")
        withVideo.prepare(items: [photo, video], currentID: video.id, context: context)
        check(warmedVideos.count == 1 && releasedVideos.isEmpty, "选中邻页不释放或重新准备播放器")
        withVideo.close()
        check(releasedVideos == warmedVideos, "关闭画廊同时释放预备的视频播放器")

        var activeVideos: Set<URL> = []
        let videoWindow = ChatPhotoBrowserResources(warmImage: { _ in {} }, warmVideo: { file in
            activeVideos.insert(file)
            return { activeVideos.remove(file) }
        })
        let videos = (1...4).map { message("clip-\($0)", type: 2) }
        videoWindow.prepare(items: videos, currentID: "clip-2", context: context)
        for clip in videos.prefix(3) {
            await videoWindow.previews[clip.id]?.waitForPending(clip.id)
            videoWindow.previews[clip.id]?.finish(clip.id)
            await videoWindow.waitForLoad(clip.id)
        }
        check(activeVideos.count == 3, "多视频只预备三页播放器")
        videoWindow.prepare(items: videos, currentID: "clip-3", context: context)
        check(activeVideos.count == 2 && !activeVideos.contains(URL(fileURLWithPath: "/tmp/clip-1.mp4")), "翻页仅释放离开三页窗口的视频")
        let pendingClip = videoWindow.previews["clip-4"]!
        await pendingClip.waitForPending("clip-4")
        var waiting = false
        let lateVideo = Task { waiting = true; await videoWindow.waitForLoad("clip-4") }
        while !waiting { await Task.yield() }
        videoWindow.close()
        pendingClip.finish("clip-4")
        await lateVideo.value
        check(activeVideos.isEmpty, "关闭后的迟到邻页下载不能重新创建播放器")

        let closingPage = GalleryLifecycleHarness(context: context, items: [video, photo])
        let closing = Task { await closingPage.load() }
        while closingPage.resources.previews["video"] == nil { await Task.yield() }
        let closingPreview = closingPage.resources.previews["video"]!
        await closingPreview.waitForPending("video")
        ChatRuntime.shared.valid = false; ChatRuntime.shared.cleanup?()
        closingPreview.finish("video"); await closing.value
        check(closingPage.playback.file == nil && closingPage.resources.previews.isEmpty, "AUTH退出取消整个窗口且迟到结果不能重播")
        print("Gallery checks: \(checks - failures)/\(checks)")
        if failures > 0 { exit(1) }
    }
}
