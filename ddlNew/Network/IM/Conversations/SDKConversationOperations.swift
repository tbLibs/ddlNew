// Created by taobo on 2026/10/13.
import Foundation
import ObjectiveC
import NoaChatCore

extension SDKConversationsClient: ConversationOperationsClient {
    /// 使用真实会话接口，成功后重读 SDK 快照而不提前修改展示状态。
    func perform(_ action: ConversationAction, conversation: ConversationRecord, userUID: String) async throws {
        let sdk = NoaIMSDKManager.sharedTool()
        let loaded: LingIMSessionModel? = sdk.toolCheckMySession(with: conversation.id)
        guard sdk.myUserID() == userUID, sdk.isUserDatabaseReady(),
              let initial = loaded,
              ConversationActionPolicy.allowed(for: conversation).contains(action) else {
            throw UserSessionError.databaseNotReady
        }
        let runID = observationGeneration
        let isGroup = conversation.kind == .group
        let latest: NoaIMChatMessageModel? = initial.sessionLatestMessage ?? sdk.toolGetLatestChatMessage(withSessionID: conversation.id)
        let sessionSID = initial.sessionLatestServerMsgID ?? ""
        let messageSID = latest?.serviceMsgID ?? ""
        let latestTime = initial.sessionLatestTime
        let lastMessageID = sessionSID.isEmpty ? messageSID : sessionSID
        let unreadAtStart = max(0, initial.sessionUnreadCount)
        let markingUnread = initial.sessionUnreadCount == 0 && initial.readTag == 0
        let route = ChatRoute(id: conversation.id, kind: conversation.kind, title: conversation.title, avatarURL: conversation.avatarURL)
        guard let readContext = ChatRuntime.shared.context(for: route), readContext.userUID == userUID else { throw CancellationError() }
        let readClear = action == .toggleUnread && !markingUnread ? ChatRuntime.shared.beginReadCountClear(context: readContext, count: unreadAtStart, boundaryID: lastMessageID) : nil
        var values: [String: Any] = ["userUid": userUID]
        switch action {
        case .togglePin, .toggleMute:
            values[isGroup ? "groupId" : "friendUserUid"] = conversation.id
            let enabled = action == .togglePin ? initial.sessionTop : initial.sessionNoDisturb
            values["status"] = enabled ? 0 : 1
        case .toggleUnread, .delete:
            values["peerUid"] = conversation.id
            values["dialogType"] = isGroup ? 1 : 0
            if action == .toggleUnread {
                values["readTag"] = markingUnread ? 1 : 0
                // 标记未读沿 xgd 优先发送正文 SID；清除未读则沿用计数起点的边界。
                let requestSID = markingUnread && !messageSID.isEmpty ? messageSID : lastMessageID
                if !requestSID.isEmpty { values["latestSMsgId"] = requestSID }
            }
        }
        let params = NSMutableDictionary(dictionary: values)
        let waiter = SDKChatRequestWaiter<Bool>()
        let accepted = try await waiter.run {
            let success: LingIMSuccessCallback = { data, _ in
                let accepted: Bool
                switch action {
                case .toggleUnread, .delete:
                    // 与 xgd 一致，这两个接口通过 SDK 成功回调确认；不要求 data 为布尔值。
                    // 保留对显式 false 的识别。
                    accepted = (data as? NSNumber)?.boolValue ?? true
                case .togglePin, .toggleMute:
                    accepted = (data as? NSNumber)?.boolValue ?? false
                }
                Task { @MainActor in waiter.finish(.success(accepted)) }
            }
            let failure: LingIMFailureCallback = { code, message, _ in
                let detail = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                Task { @MainActor in
                    waiter.finish(.failure(ChatClientError.unavailable(detail.isEmpty ? "会话操作失败（\(code)），请稍后重试" : "\(detail)（\(code)）")))
                }
            }
            switch action {
            case .togglePin:
                if isGroup { sdk.groupConversationTop(params, onSuccess: success, onFailure: failure) }
                else { sdk.singleConversationTop(params, onSuccess: success, onFailure: failure) }
            case .toggleMute:
                if isGroup { sdk.groupConversationPromt(params, onSuccess: success, onFailure: failure) }
                else { sdk.singleConversationPromt(params, onSuccess: success, onFailure: failure) }
            case .toggleUnread: sdk.conversationReadedStatus(params, onSuccess: success, onFailure: failure)
            case .delete: sdk.deleteServerConversation(params, onSuccess: success, onFailure: failure)
            }
        }
        try Task<Never, Never>.checkCancellation()
        objc_sync_enter(sdk)
        defer { objc_sync_exit(sdk) }
        guard runID == observationGeneration, sdk.myUserID() == userUID, sdk.isUserDatabaseReady(), ChatRuntime.shared.isCurrent(readContext) else {
            throw CancellationError()
        }
        guard accepted else { throw ChatClientError.unavailable("服务端未接受会话操作，请重试") }
        let updated: LingIMSessionModel? = sdk.toolCheckMySession(with: conversation.id)
        guard let current = updated else { return }
        if action == .delete {
            // 删除请求后若有新消息，保留新会话，不能移除服务端边界之后的消息入口。
            let latestNow: NoaIMChatMessageModel? = current.sessionLatestMessage ?? sdk.toolGetLatestChatMessage(withSessionID: conversation.id)
            guard (current.sessionLatestServerMsgID ?? "") == sessionSID,
                  (latestNow?.serviceMsgID ?? "") == messageSID,
                  current.sessionLatestTime == latestTime else { return }
            guard sdk.toolDeleteSessionModel(with: current, andDeleteAllChatModel: false) else {
                throw ChatClientError.unavailable("无法更新本机会话，请刷新确认状态")
            }
        } else if action == .toggleUnread {
            current.readTag = markingUnread ? 1 : 0
            if !markingUnread {
                // 请求发出后到达的新消息仍保持未读，不能按新快照直接清零。
                let nowLatest: NoaIMChatMessageModel? = current.sessionLatestMessage ?? sdk.toolGetLatestChatMessage(withSessionID: conversation.id)
                let latestNowID = current.sessionLatestServerMsgID?.isEmpty == false ? current.sessionLatestServerMsgID ?? "" : nowLatest?.serviceMsgID ?? ""
                if latestNowID == lastMessageID { current.sessionUnreadCount = 0 }
                else {
                    // 他端可能已减少旧未读；最新消息已变化时至少保留一条新未读。
                    current.sessionUnreadCount = current.sessionUnreadCount == 0 ? 0 : max(1, current.sessionUnreadCount - unreadAtStart)
                }
            }
            let saved = sdk.toolUpdateSession(with: current)
            if let readClear {
                // 服务端全清已受理，即使本地写失败也撤销旧成员资格；计数只取实际保存后的SDK行。
                let stored: LingIMSessionModel? = saved ? current : sdk.toolCheckMySession(with: conversation.id)
                let latestNow = stored?.sessionLatestServerMsgID ?? stored?.sessionLatestMessage?.serviceMsgID ?? ""
                ChatRuntime.shared.confirmReadCountClear(readClear, context: readContext, count: stored?.sessionUnreadCount, latestID: latestNow)
            }
            guard saved else { throw ChatClientError.unavailable("无法更新本机会话，请刷新确认状态") }
        }
    }
}
