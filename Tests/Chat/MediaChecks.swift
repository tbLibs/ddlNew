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
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("photo.jpg")
        try! Data(repeating: 7, count: 2048).write(to: file)
        let task = Task { await store.send(ChatAttachment(file: file, type: 4, name: "voice.m4a", bytes: 900, duration: 0.5), context: context) { _ in count += 1 } }
        await task.value
        precondition(count == 0 && store.errorMessage != nil, "不足1024字节语音不能上传发送")
        let short = ChatMediaStore(client: CompletedMedia())
        for duration in [0.99, Double.nan, Double.infinity, 60.1] {
            await short.send(ChatAttachment(file: file, type: 4, name: "voice.m4a", bytes: 2048, duration: duration), context: context) { _ in preconditionFailure("非法时长不能上传或入队") }
            precondition(short.errorMessage != nil)
        }
        var acceptedVoice = 0
        for duration in [1.0, 60.0] {
            await short.send(ChatAttachment(file: file, type: 4, name: "voice.m4a", bytes: 2048, duration: duration), context: context) { _ in acceptedVoice += 1 }
        }
        precondition(acceptedVoice == 2, "合法语音上下限可上传入队")
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
        let cover = root.appendingPathComponent("cover.jpg")
        try! Data([1, 2, 3]).write(to: cover)
        await completed.send(ChatAttachment(file: file, type: 2, name: "video.mp4", bytes: 2048, duration: 9, width: 1920, height: 1080, previewFile: cover),
                             context: context, stage: { staged = $0 }, discard: { _ in preconditionFailure("成功不应删除预览") }, enqueue: { enqueued = $0 })
        precondition(staged?.localMediaPreviewURL != nil && staged?.localMediaPreviewURL != file && staged?.isMediaUploading == true, "上传前应显示本地视频封面")
        precondition(enqueued?.localID == staged?.localID && enqueued?.localMediaPreviewURL == nil && enqueued?.isMediaUploading == false && enqueued?.thumbnail == "/remote/cover", "完成后同一消息切远端封面")

        let failed = ChatMediaStore(client: FailedMedia())
        var discardedID: String?
        var failedStageID: String?
        var failedMessage: ChatMessageRecord?
        await failed.send(ChatAttachment(file: file, type: 1, name: "photo.jpg", bytes: 2048, width: 640, height: 480), context: context,
                          stage: { failedStageID = $0.localID; precondition($0.localMediaPreviewURL != nil) },
                          discard: { discardedID = $0 }, failed: { failedMessage = $0 }, enqueue: { _ in preconditionFailure("失败不能入队") })
        precondition(discardedID == nil && failedStageID != nil && failed.errorMessage == nil, "上传失败保留原气泡和失败标记，不再弹Toast")

        precondition(failedMessage?.state == .failed && failedMessage?.isMediaUploading == false, "失败停止菊花并保留红色失败状态")
        let retainedFile = failedMessage!.localMediaFileURL!
        precondition(try! Data(contentsOf: retainedFile) == Data(repeating: 7, count: 2048), "失败原件必须持久保留")
        defer { ChatUploadFiles.remove(retainedFile) }

        let retryClient = CompletedMedia()
        let retryStore = ChatMediaStore(client: retryClient)
        var retryMessage: ChatMessageRecord?
        await retryStore.retry(failedMessage!, context: context, stage: { _ in }, discard: { _ in }, failed: { _ in }, enqueue: { retryMessage = $0 })
        precondition(retryMessage?.localID == failedStageID && retryMessage?.resource == "/remote/media" && retryMessage?.localMediaFileURL == nil, "重试必须复用原ID并上传后再入SDK队列")
        precondition(!FileManager.default.fileExists(atPath: retainedFile.path), "上传入队后释放本机重传原件")

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
        let chatClient = SuspendedChatClient()
        chatClient.policy.canUpload = true
        let chat = ChatStore(client: chatClient)
        await chat.open(context)
        let chatMedia = ChatMediaStore(client: FailedMedia())
        await chatMedia.send(ChatAttachment(file: file, type: 1, name: "photo.jpg", bytes: 2048), context: context,
            stage: { try chat.beginMediaUpload($0) }, discard: { chat.discardMediaUpload($0) },
            failed: { chat.failMediaUpload($0) }, enqueue: { try chat.sendAttachment($0) })
        precondition(chat.messages.count == 1 && chat.messages[0].state == .failed && chat.messages[0].localMediaPreviewURL != nil, "真实Store上传失败保留图片气泡")
        let persisted = chat.messages[0]
        defer { ChatUploadFiles.remove(persisted.localMediaFileURL) }
        chat.close()
        await chat.open(context)
        chat.mediaRetryClient = retryStore
        chat.retry(persisted.id); chat.retry(persisted.id)
        let deadline = Date().addingTimeInterval(5)
        while !chat.busyIDs.isEmpty && Date() < deadline { await Task.yield() }
        precondition(chatClient.sent.count == 1 && chat.messages.count == 1 && chat.messages[0].state == .sending, "重进后点击失败重试保留原条且防重复入队")
        chatClient.callback?(.failed(localID: persisted.localID, reason: .timeout))
        precondition(chat.messages[0].state == .failed && chat.errorMessage == nil, "图片SDK发送超时仅更新失败气泡，不弹Toast")
        chatClient.callback?(.ack(localID: persisted.localID, serverID: "ack-photo", timestamp: 900))
        precondition(chat.messages[0].state == .sent && chat.sendSuccessRevision == 1, "原条仅在ACK之后成功")
        // 再次失败、缓存刷新与取消只能影响原条，不能恢复菊花或吞掉失败记录。
        let retryFailure = ChatMediaStore(client: FailedMedia())
        await chatMedia.send(ChatAttachment(file: file, type: 1, name: "second.jpg", bytes: 2048), context: context,
            stage: { try chat.beginMediaUpload($0) }, discard: { chat.discardMediaUpload($0) },
            failed: { chat.failMediaUpload($0) }, enqueue: { try chat.sendAttachment($0) })
        let second = chat.messages.first { $0.state == .failed }!
        defer { ChatUploadFiles.remove(second.localMediaFileURL) }
        chat.mediaRetryClient = retryFailure; chat.retry(second.id)
        await waitForRetry(chat)
        precondition(chat.messages.first { $0.id == second.id }?.state == .failed && FileManager.default.fileExists(atPath: second.localMediaFileURL!.path), "再次上传失败保留原件与原条")
        let pausedRetryClient = PausedMedia(); let pausedRetry = ChatMediaStore(client: pausedRetryClient)
        chat.mediaRetryClient = pausedRetry; chat.retry(second.id)
        while pausedRetryClient.pending == nil { await Task.yield() }
        chatClient.callback?(.refresh)
        precondition(chat.messages.first { $0.id == second.id }?.isMediaUploading == true, "旧失败缓存回读不能覆盖当前重传状态")
        pausedRetry.cancel()
        pausedRetryClient.pending?.resume(returning: ChatUploadedAttachment(resource: "/late", thumbnail: "/late-cover"))
        await waitForRetry(chat)
        precondition(chat.messages.first { $0.id == second.id }?.state == .failed && chatClient.sent.count == 1, "取消重传保留失败原条且迟到结果不能入队")
        chatClient.policy.canSend = false; chat.retry(second.id)
        precondition(chat.messages.first { $0.id == second.id }?.state == .failed && !pausedRetry.isUploading, "权限变化禁止重传且保留原条")
        chatClient.policy.canSend = true
        try! FileManager.default.removeItem(at: second.localMediaFileURL!)
        chat.retry(second.id); await waitForRetry(chat)
        precondition(chat.messages.first { $0.id == second.id }?.state == .failed && pausedRetry.errorMessage != nil && chatClient.sent.count == 1, "原件丢失必须提示且不发送空资源")
        let uploadedButRejected = ChatMediaStore(client: CompletedMedia())
        await uploadedButRejected.send(ChatAttachment(file: file, type: 1, name: "uploaded.jpg", bytes: 2048), context: context,
            stage: { try chat.beginMediaUpload($0) }, discard: { chat.discardMediaUpload($0) },
            failed: { chat.failMediaUpload($0) }, enqueue: { _ in throw ChatClientError.unavailable("消息入队失败") })
        precondition(uploadedButRejected.errorMessage == nil, "图片入队失败保留失败气泡，不弹Toast")
        let queueFailure = chat.messages.first { $0.state == .failed && !$0.resource.isEmpty }!
        defer { ChatUploadFiles.remove(queueFailure.localMediaFileURL) }
        precondition(queueFailure.localMediaPreviewURL != nil && !queueFailure.isMediaUploading, "上传后入队失败也必须保留失败气泡和本地图片")
        chat.retry(queueFailure.id)
        precondition(chatClient.sent.count == 2 && chatClient.sent.last?.localID == queueFailure.localID && chatClient.sent.last?.resource == "/remote/media", "已有云地址重试直接复用资源，不重新上传或新建消息")
        chatClient.policy.canDelete = true
        let deleted = await chat.perform(.delete, id: second.id)
        precondition(deleted && !chat.messages.contains { $0.id == second.id }, "上传失败原条仍可使用现有本机删除")
        await chatMedia.send(ChatAttachment(file: file, type: 1, name: "clear.jpg", bytes: 2048), context: context,
            stage: { try chat.beginMediaUpload($0) }, discard: { chat.discardMediaUpload($0) },
            failed: { chat.failMediaUpload($0) }, enqueue: { try chat.sendAttachment($0) })
        let clearing = chat.messages.first { $0.state == .failed }!
        let clearClient = PausedMedia(); let clearMedia = ChatMediaStore(client: clearClient)
        chat.mediaRetryClient = clearMedia; chat.retry(clearing.id)
        while clearClient.pending == nil { await Task.yield() }
        chatClient.callback?(.cleared)
        clearClient.pending?.resume(returning: ChatUploadedAttachment(resource: "/cleared", thumbnail: "/cover"))
        await waitForRetry(chat)
        precondition(chat.messages.isEmpty && chatClient.sent.count == 2 && !FileManager.default.fileExists(atPath: clearing.localMediaFileURL!.path), "清历史使旧重传结果失效且释放原件")
        print("Media checks: failure retention, enqueue failure, reopen, retry, duplicates, refresh, cancellation, missing file, delete, clear and ACK passed")
    }
    @MainActor static func waitForRetry(_ chat: ChatStore) async {
        let deadline = Date().addingTimeInterval(5)
        while !chat.busyIDs.isEmpty && Date() < deadline { await Task.yield() }
        precondition(chat.busyIDs.isEmpty, "重传任务必须结束")
    }

}
