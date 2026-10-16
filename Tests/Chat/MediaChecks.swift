import Foundation

@MainActor final class PausedMedia: ChatMediaClient {
    var pending: CheckedContinuation<ChatUploadedAttachment, Error>?
    /// 暂停上传后允许旧回调返回，验证取消不能误发送。
    func upload(_ attachment: ChatAttachment, context: ChatContext, progress: @escaping @MainActor (Double) -> Void) async throws -> ChatUploadedAttachment { try await withCheckedThrowingContinuation { pending = $0 } }
    /// 故意不结束旧等待，模拟SDK无法取消的底层请求。
    func cancel() {}
}

@MainActor final class CompletedMedia: ChatMediaClient {
    func upload(_ attachment: ChatAttachment, context: ChatContext, progress: @escaping @MainActor (Double) -> Void) async throws -> ChatUploadedAttachment {
        progress(1)
        return ChatUploadedAttachment(resource: "/remote/media", thumbnail: "/remote/cover")
    }
    func cancel() {}
}

@MainActor final class FailedMedia: ChatMediaClient {
    func upload(_ attachment: ChatAttachment, context: ChatContext, progress: @escaping @MainActor (Double) -> Void) async throws -> ChatUploadedAttachment {
        throw ChatClientError.unavailable("上传失败")
    }
    func cancel() {}
}

@main struct MediaChecks {
    /// 先失败后实现取消、归属和语音字节阈值。
    @MainActor static func main() async {
        let client = PausedMedia(); let store = ChatMediaStore(client: client)
        let context = ChatContext(userUID: "u", tenantID: "club", sessionID: UUID(), route: ChatRoute(id: "p", kind: .single, title: "", avatarURL: ""))
        var count = 0
        let file = URL(fileURLWithPath: "/tmp/voice.m4a")
        let task = Task { await store.send(ChatAttachment(file: file, type: 4, name: "voice.m4a", bytes: 900, duration: 0.5), context: context) { _ in count += 1 } }
        await task.value
        precondition(count == 0 && store.errorMessage != nil, "不足1024字节语音不能上传发送")
        let uploading = Task { await store.send(ChatAttachment(file: file, type: 5, name: "文档.txt", bytes: 1024), context: context) { _ in count += 1 } }
        await Task.yield(); store.cancel()
        client.pending?.resume(returning: ChatUploadedAttachment(resource: "/real/file", thumbnail: ""))
        await uploading.value
        precondition(count == 0 && !store.isUploading, "取消后的旧上传结果不能入消息队列")
        precondition(!ChatAttachmentPolicy.allowedBytes(1024, maximumMB: Int64.max), "配额损坏不得溢出崩溃")
        precondition(ChatAttachmentPolicy.allowedBytes(1024 * 1024, maximumMB: 1) && !ChatAttachmentPolicy.allowedBytes(1024 * 1024 + 1, maximumMB: 1), "字节上限包含临界值")

        let completed = ChatMediaStore(client: CompletedMedia())
        var staged: ChatMessageRecord?
        var enqueued: ChatMessageRecord?
        let cover = URL(fileURLWithPath: "/tmp/local-cover.jpg")
        await completed.send(ChatAttachment(file: file, type: 2, name: "video.mp4", bytes: 2048, duration: 9, width: 1920, height: 1080, previewFile: cover),
                             context: context, stage: { staged = $0 }, discard: { _ in preconditionFailure("成功不应删除预览") }, enqueue: { enqueued = $0 })
        precondition(staged?.localMediaPreviewURL == cover && staged?.isMediaUploading == true, "上传前应显示本地视频封面")
        precondition(enqueued?.localID == staged?.localID && enqueued?.localMediaPreviewURL == nil && enqueued?.isMediaUploading == false && enqueued?.thumbnail == "/remote/cover", "完成后同一消息切远端封面")

        let failed = ChatMediaStore(client: FailedMedia())
        var discardedID: String?
        var failedStageID: String?
        await failed.send(ChatAttachment(file: file, type: 1, name: "photo.jpg", bytes: 2048, width: 640, height: 480), context: context,
                          stage: { failedStageID = $0.localID; precondition($0.localMediaPreviewURL == file) },
                          discard: { discardedID = $0 }, enqueue: { _ in preconditionFailure("失败不能入队") })
        precondition(discardedID == failedStageID && failed.errorMessage != nil, "上传失败应清理预览并提示")

        let cancelledClient = PausedMedia()
        let cancelled = ChatMediaStore(client: cancelledClient)
        var cancelledStageID: String?
        var cancelledDiscardID: String?
        let cancelledTask = Task { await cancelled.send(ChatAttachment(file: file, type: 1, name: "photo.jpg", bytes: 2048), context: context,
            stage: { cancelledStageID = $0.localID }, discard: { cancelledDiscardID = $0 }, enqueue: { _ in preconditionFailure("取消不能入队") }) }
        while cancelledClient.pending == nil { await Task.yield() }
        cancelled.cancel()
        cancelledClient.pending?.resume(returning: ChatUploadedAttachment(resource: "/late", thumbnail: ""))
        await cancelledTask.value
        precondition(cancelledDiscardID == cancelledStageID && !cancelled.isUploading, "取消应立即移除本地预览")
        print("Media checks: 7 passed")
    }
}
