//
//  SDKChatActionsClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore

/// 消息编辑和转发使用SDK既有Protobuf转换，不修改生成协议文件。
@MainActor final class SDKChatActionsClient {
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }

    /// 编辑保留原双ID、发送时间与已读计数，仅成功回执后替换正文。
    func edit(_ message: ChatMessageRecord, text: String, mentions: [ChatMentionSegment]? = nil, context: ChatContext) async throws -> ChatMessageRecord {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ChatClientError.permission("编辑内容不能为空") }
        let client = SDKChatClient(validSession: { ChatRuntime.shared.isCurrent($0) })
        client.observe(context: context, onEvent: { _ in }); defer { client.stop() }
        try await client.refreshPermissions(context: context)
        let permission = try client.permissions(context: context)
        guard ChatActionPolicy.allowed(for: message, userUID: context.userUID, permission: permission).contains(.edit) else { throw ChatClientError.permission("当前消息不允许编辑") }
        let original: NoaIMChatMessageModel? = sdk.toolGetOneChatMessage(withMessageID: message.localID, sessionID: context.route.id)
        guard let original else { throw ChatClientError.unavailable("原消息已不存在") }
        let request = LingIMModelTool.shared().getChatMessageModel(fromLingIMChatMessageModel: original)
        request.sMsgId = message.serverID; request.sendTime = message.timestamp
        let edited = mentions.map { (text, $0) } ?? ChatMentionEngine.editing(old: message.text, new: text, segments: message.mentions)
        var prepared = message; prepared.text = edited.0; prepared.mentions = edited.1; prepared.type = edited.1.isEmpty ? 0 : 10
        prepared = try client.prepareMessage(prepared, context: context)
        if prepared.mentions.isEmpty {
            request.mType = IMChatMessage_MessageType(rawValue: 0)!
            let body = TextMessage(); body.content = prepared.text; body.ext = original.textExt ?? original.atExt ?? ""
            request.textMessage = body
        } else {
            request.mType = IMChatMessage_MessageType(rawValue: 10)!
            let body = AtMessage(); body.content = ChatMentionEngine.wireText(prepared.text, segments: prepared.mentions); body.ext = original.atExt ?? original.textExt ?? ""
            body.atInfoArray = NSMutableArray(array: prepared.mentions.map { segment -> AtInfo in let info = AtInfo(); info.uId = segment.userUID; info.uNick = segment.name; return info })
            request.atMessage = body
        }
        guard let data = request.data() else { throw ChatClientError.invalidResponse }
        _ = try await client.request(context: context) { success, failure in self.sdk.editMessage(data, onSuccess: success, onFailure: failure) }
        try client.validate(context)
        original.messageType = CIMChatMessageType(rawValue: UInt(prepared.type))!
        if prepared.type == 10 {
            original.atContent = ChatMentionEngine.wireText(prepared.text, segments: prepared.mentions); original.showContent = prepared.text
            original.atUsersInfoList = prepared.mentions.map { [$0.userUID: $0.name] }; original.textContent = nil
        } else { original.textContent = prepared.text; original.atContent = nil; original.atUsersInfoList = nil }
        sdk.toolInsertOrUpdateChatMessage(with: original)
        return SDKChatMessageMapper.record(original, userUID: context.userUID)
    }

    /// 置顶状态先查询再选择个人范围；群全局需要管理权限另显式提交。
    func pin(_ message: ChatMessageRecord, context: ChatContext, global: Bool, removing: Bool = false) async throws {
        let client = SDKChatClient(validSession: { ChatRuntime.shared.isCurrent($0) })
        client.observe(context: context, onEvent: { _ in }); defer { client.stop() }
        try await client.refreshPermissions(context: context)
        let permission = try client.permissions(context: context)
        guard ChatActionPolicy.allowed(for: message, userUID: context.userUID, permission: permission).contains(.pin), context.route.kind != .group || !global || permission.role > 0 else { throw ChatClientError.permission("当前消息不能置顶到所有成员") }
        var values: [String: Any] = ["userUid": context.userUID, "smsgId": message.serverID]
        values[context.route.kind == .group ? "groupId" : "friendUid"] = context.route.id
        let current = try await client.request(context: context) { success, failure in
            if context.route.kind == .group { self.sdk.messageQueryGroupMsgStatus(with: NSMutableDictionary(dictionary: values), onSuccess: success, onFailure: failure) }
            else { self.sdk.messageQueryUserMsgStatus(with: NSMutableDictionary(dictionary: values), onSuccess: success, onFailure: failure) }
        }
        guard let rawType = (current["type"] as? NSNumber)?.intValue ?? Int(current["type"] as? String ?? ""), let state = ChatPinStatus(type: rawType) else { throw ChatClientError.invalidResponse }
        if removing && !(global ? state.global : state.personal) { throw ChatClientError.unavailable("该范围的消息置顶已不存在，请刷新") }
        if !removing && (global ? state.global : state.personal) { return }
        values["msgStatus"] = removing ? (global ? 3 : 4) : (global ? 1 : 2)
        _ = try await client.request(context: context) { success, failure in
            if context.route.kind == .group { self.sdk.groupSetMsgTop(with: NSMutableDictionary(dictionary: values), onSuccess: success, onFailure: failure) }
            else { self.sdk.messageSetMsgTop(with: NSMutableDictionary(dictionary: values), onSuccess: success, onFailure: failure) }
        }
    }

    /// 置顶条和列表使用真实查询结果，已删除撤回原文不继续展示。
    func pinned(context: ChatContext) async throws -> [ChatMessageRecord] {
        let client = SDKChatClient(validSession: { ChatRuntime.shared.isCurrent($0) })
        client.observe(context: context, onEvent: { _ in }); defer { client.stop() }
        var values: [String: Any] = ["userUid": context.userUID]
        values[context.route.kind == .group ? "groupId" : "friendUid"] = context.route.id
        values["type"] = 1
        let response = try await client.request(context: context) { success, failure in
            if context.route.kind == .group { self.sdk.messageQueryGroupTopMsgList(with: NSMutableDictionary(dictionary: values), onSuccess: success, onFailure: failure) }
            else { self.sdk.messageQueryUserTopMsgs(with: NSMutableDictionary(dictionary: values), onSuccess: success, onFailure: failure) }
        }
        try client.validate(context)
        let rows = response["_value"] as? [[String: Any]] ?? response["rows"] as? [[String: Any]] ?? []
        return rows.compactMap { row in
            let sid = row["smsgId"] as? String ?? row["sMsgId"] as? String ?? ""
            let cached: NoaIMChatMessageModel? = self.sdk.toolGetOneChatMessage(withServiceMessageID: sid, sessionID: context.route.id)
            let record = SDKChatMessageMapper.record(cached ?? SDKChatMessageMapper.historyModel(row, context: context), userUID: context.userUID)
            return record.status == .normal && [0, 10].contains(record.type) && record.referenceID.isEmpty ? record : nil
        }
    }

    /// 查询当前个人和全局状态，界面按真实状态生成可用范围按钮。
    func pinStatus(_ message: ChatMessageRecord, context: ChatContext) async throws -> ChatPinStatus {
        let client = SDKChatClient(validSession: { ChatRuntime.shared.isCurrent($0) })
        client.observe(context: context, onEvent: { _ in }); defer { client.stop() }
        let values: [String: Any] = ["userUid": context.userUID, context.route.kind == .group ? "groupId" : "friendUid": context.route.id, "smsgId": message.serverID]
        let response = try await client.request(context: context) { success, failure in
            if context.route.kind == .group { self.sdk.messageQueryGroupMsgStatus(with: NSMutableDictionary(dictionary: values), onSuccess: success, onFailure: failure) }
            else { self.sdk.messageQueryUserMsgStatus(with: NSMutableDictionary(dictionary: values), onSuccess: success, onFailure: failure) }
        }
        guard let type = (response["type"] as? NSNumber)?.intValue ?? Int(response["type"] as? String ?? ""), let result = ChatPinStatus(type: type) else { throw ChatClientError.invalidResponse }
        return result
    }

    /// 先合规预检再逐对象回执，缺少任一消息服务端ID都不能当成功。
    func forward(_ messages: [ChatMessageRecord], from context: ChatContext, to recipient: ChatRoute, merged: Bool, onEnqueued: @MainActor ([ChatMessageRecord]) -> Void = { _ in }) async throws -> [ChatMessageRecord] {
        guard !messages.isEmpty, messages.count <= 100,
              let destination = ChatRuntime.shared.context(for: recipient), destination.userUID == context.userUID else { throw ChatClientError.sessionExpired }
        let source = SDKChatClient(validSession: { ChatRuntime.shared.isCurrent($0) })
        source.observe(context: context, onEvent: { _ in }); defer { source.stop() }
        let target = SDKChatClient(validSession: { ChatRuntime.shared.isCurrent($0) })
        target.observe(context: destination, onEvent: { _ in }); defer { target.stop() }
        try await target.refreshPermissions(context: destination)
        guard try target.permissions(context: destination).canSend else { throw ChatClientError.permission("接收会话当前不允许发送") }
        let permission = try source.permissions(context: context)
        guard messages.allSatisfy({ ChatActionPolicy.allowed(for: $0, userUID: context.userUID, permission: permission).contains(.forward) }) else { throw ChatClientError.permission("部分消息已不允许转发") }
        let preflight = try await source.request(context: context) { success, failure in
            self.sdk.transpondComplianceMessage(NSMutableDictionary(dictionary: ["userUid": context.userUID, "dialogs": [["dialogId": recipient.id, "dialogType": recipient.kind == .group ? 1 : 0]], "forwardCount": merged ? 1 : messages.count]), onSuccess: success, onFailure: failure)
        }
        if let invalid = preflight["_value"] as? [Any], !invalid.isEmpty { throw ChatClientError.permission("接收对象未通过转发检查，请选择其他会话") }
        let ordered = messages.sorted { $0.timestamp == $1.timestamp ? $0.id < $1.id : $0.timestamp < $1.timestamp }
        var models: [NoaIMChatMessageModel] = []
        for message in ordered {
            let original: NoaIMChatMessageModel? = sdk.toolGetOneChatMessage(withMessageID: message.localID, sessionID: context.route.id)
            guard let original else { throw ChatClientError.unavailable("转发原消息已不存在") }; models.append(original)
        }
        if merged {
            let forward = ForwardMessage(); forward.type = recipient.kind == .group ? 1 : 0; forward.title = context.route.title + "的聊天记录"
            forward.messageListArray = NSMutableArray(array: models.map { LingIMModelTool.shared().getChatMessageModel(fromLingIMChatMessageModel: $0) })
            var record = ChatMessageRecord(localID: UUID().uuidString, conversationID: recipient.id, senderID: destination.userUID, senderName: "我", type: 18, timestamp: Int64(Date().timeIntervalSince1970 * 1000))
            record.nestedMessages = ordered
            let model = target.makeModel(record, context: destination); model.forwardMessage = forward; model.forwardMessageProtobuf = forward.delimitedData()
            try target.validate(destination); sdk.toolSendChatMessage(with: model)
            onEnqueued([record]); return [record]
        }
        let request = IMChatMessageList(); request.source = "IOS"
        request.iMchatMessageArray = NSMutableArray(array: models.map { LingIMModelTool.shared().getChatMessageModel(fromLingIMChatMessageModel: $0) })
        let receiver = ToMessage(); receiver.chatType = ChatType(rawValue: recipient.kind == .group ? 1 : 0)!; receiver.to = recipient.id
        let ids = ordered.map { _ in UUID().uuidString }; receiver.msgIdArray = NSMutableArray(array: ids); request.toMessageArray = NSMutableArray(object: receiver)
        guard let data = request.data() else { throw ChatClientError.invalidResponse }
        let response = try await source.request(context: context) { success, failure in self.sdk.transpondMessage(data, onSuccess: success, onFailure: failure) }
        try target.validate(destination)
        let failed = response["failId"] as? [String] ?? []
        guard !failed.contains(recipient.id), let perReceiver = response["sMsgId"] as? [[String]], let serverIDs = perReceiver.first, serverIDs.count == ordered.count, serverIDs.allSatisfy({ !$0.isEmpty }) else { throw ChatClientError.unavailable("部分转发未成功，未确认的消息不会显示为成功") }
        var result: [ChatMessageRecord] = []
        for index in ordered.indices {
            var item = ordered[index]; item.localID = ids[index]; item.serverID = serverIDs[index]; item.referenceID = ""; item.state = .sent; item.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
            let model = target.makeModel(ChatMessageRecord(localID: item.localID, serverID: item.serverID, conversationID: recipient.id, senderID: context.userUID, senderName: "我", type: item.type == 10 ? 0 : item.type, text: item.text, timestamp: item.timestamp, state: .sent, resource: item.resource, thumbnail: item.thumbnail, fileName: item.fileName, size: item.size, duration: item.duration), context: destination)
            // 本人转发已发送的消息不能增加目标会话的未读数。
            model.chatMessageReaded = true
            model.messageSendType = CIMChatMessageSendType(rawValue: 1)!; sdk.toolInsertOrUpdateSession(with: model, isRemind: true)
            result.append(SDKChatMessageMapper.record(model, userUID: context.userUID))
        }
        return result
    }
}
