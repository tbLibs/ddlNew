import Foundation

@MainActor final class PausedMedia: ChatMediaClient {
    var pending: CheckedContinuation<ChatUploadedAttachment, Error>?
    /// 暂停上传后允许旧回调返回，验证取消不能误发送。
    func upload(_ attachment: ChatAttachment, context: ChatContext, progress: @escaping @MainActor (Double) -> Void) async throws -> ChatUploadedAttachment { try await withCheckedThrowingContinuation { pending = $0 } }
    /// 故意不结束旧等待，模拟SDK无法取消的底层请求。
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
        print("Media checks: 4 passed")
    }
}
