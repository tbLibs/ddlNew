//
//  MediaAdversarialChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

@MainActor final class AcceptanceMediaClient: ChatMediaClient {
    var waits: [CheckedContinuation<ChatUploadedAttachment, Error>] = []
    var uploads = 0
    var cancelCount = 0
    /// 上传挂起后由测试明确返回，模拟网络取消无法撤销服务器结果。
    func upload(_ attachment: ChatAttachment, context: ChatContext, progress: @escaping @MainActor (Double) -> Void) async throws -> ChatUploadedAttachment {
        uploads += 1; progress(0.5)
        return try await withCheckedThrowingContinuation { waits.append($0) }
    }
    /// 保留已提交回执，用Store轮次验证迟到不进入消息队列。
    func cancel() { cancelCount += 1 }
}

@main struct MediaAdversarialChecks {
    /// 检查上传与消息入队分阶段、空录音、60秒边界、重复与取消。
    @MainActor static func main() async {
        let client = AcceptanceMediaClient(); let store = ChatMediaStore(client: client)
        let context = ChatContext(userUID: "layout-me", tenantID: "layout-only", sessionID: UUID(), route: ChatRoute(id: "layout-peer", kind: .single, title: "匿名验收", avatarURL: ""))
        var queued: [ChatMessageRecord] = []
        let empty = ChatAttachment(file: URL(fileURLWithPath: "/tmp/qa-empty"), type: 5, name: "匿名附件", bytes: 0)
        await store.send(empty, context: context) { queued.append($0) }
        precondition(client.uploads == 0 && queued.isEmpty, "空文件不得上传")
        let short = ChatAttachment(file: empty.file, type: 4, name: "匿名录音", bytes: 1023, duration: 1)
        await store.send(short, context: context) { queued.append($0) }
        precondition(client.uploads == 0, "不足1024字节不得上传")
        let long = ChatAttachment(file: empty.file, type: 4, name: "匿名录音", bytes: 1024, duration: 61)
        await store.send(long, context: context) { queued.append($0) }
        precondition(client.uploads == 0, "超过60秒不得上传")
        let valid = ChatAttachment(file: empty.file, type: 4, name: "匿名录音", bytes: 1024, duration: 60)
        let task = Task { await store.send(valid, context: context) { queued.append($0) } }
        while client.waits.isEmpty { await Task.yield() }
        await store.send(valid, context: context) { queued.append($0) }
        precondition(client.uploads == 1 && queued.isEmpty && store.isUploading, "重复发送不得新上传，上传中不先入队")
        store.cancel(); client.waits[0].resume(returning: ChatUploadedAttachment(resource: "anonymous-resource", thumbnail: "")); await task.value
        precondition(queued.isEmpty && !store.isUploading && client.cancelCount == 1, "取消后迟到上传不得入队")
        let task2 = Task { await store.send(valid, context: context) { queued.append($0) } }
        while client.waits.count < 2 { await Task.yield() }
        client.waits[1].resume(returning: ChatUploadedAttachment(resource: "anonymous-resource", thumbnail: "")); await task2.value
        precondition(queued.count == 1 && queued[0].state == .sending && queued[0].type == 4 && queued[0].duration == 60, "上传成功只入发送中，不能伪造ACK成功")
        print("Independent media acceptance: 6/6 passed")
    }
}
