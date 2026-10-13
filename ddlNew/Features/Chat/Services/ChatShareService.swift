//
//  ChatShareService.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore

@MainActor final class ChatShareService {
    /// QR与资料分享使用真实图片上传和消息发送，上传回执后仍等待SDK消息ACK。
    func sendImage(data: Data, to route: ChatRoute) async throws {
        guard let context = ChatRuntime.shared.context(for: route) else { throw ChatClientError.sessionExpired }
        let attachment = try await Task.detached { try ChatAttachmentPreparation.image(data) }.value
        defer { try? FileManager.default.removeItem(at: attachment.file) }
        let media = SDKChatMediaClient()
        ChatRuntime.shared.registerCleanup(owner: media, conversationID: route.id) { [weak media] in media?.cancel() }
        defer { media.cancel() }
        let result = try await media.upload(attachment, context: context, progress: { _ in })
        guard ChatRuntime.shared.isCurrent(context) else { throw ChatClientError.sessionExpired }
        let client = SDKChatClient(validSession: { ChatRuntime.shared.isCurrent($0) })
        client.observe(context: context, onEvent: { _ in }); defer { client.stop() }
        try await client.refreshPermissions(context: context)
        var record = ChatMessageRecord(localID: UUID().uuidString, conversationID: route.id, senderID: context.userUID, senderName: "我", type: attachment.type, timestamp: Int64(Date().timeIntervalSince1970 * 1000))
        record.resource = result.resource; record.thumbnail = result.thumbnail; record.fileName = attachment.name
        record.size = attachment.bytes; record.mediaWidth = attachment.width; record.mediaHeight = attachment.height
        try client.send(record, context: context)
    }

    /// 真实名片推荐按旧SDK字段与单/群接收者合同提交，不写假本地消息。
    func sendContactCard(contact: ContactRecord, to route: ChatRoute) async throws {
        guard !contact.isDeleted, !contact.id.isEmpty, let context = ChatRuntime.shared.context(for: route) else { throw ChatClientError.sessionExpired }
        let client = SDKChatClient(validSession: { ChatRuntime.shared.isCurrent($0) })
        client.observe(context: context, onEvent: { _ in }); defer { client.stop() }
        let permission = try client.permissions(context: context)
        if route.kind == .group {
            try await client.refreshPermissions(context: context)
        } else if !permission.canSend { throw ChatClientError.permission(permission.reason) }
        guard try client.permissions(context: context).canSend else { throw ChatClientError.permission("当前会话不允许推荐名片") }
        _ = try await client.request(context: context) { success, failure in
            NoaIMSDKManager.sharedTool().messageUserCardRecommend(NSMutableDictionary(dictionary: [
                "friendUserId": contact.id, "userUid": context.userUID,
                "receiveUsers": [["chatType": route.kind == .group ? "GROUP_CHAT" : "SINGLE_CHAT", "friendIdOrGroupId": route.id]]
            ]), onSuccess: success, onFailure: failure)
        }
    }
}
