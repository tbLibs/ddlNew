// Created by taobo on 2026/10/13.
import Foundation
import ObjectiveC
import NoaChatCore

@MainActor final class SDKGlobalSearchClient: GlobalSearchClient {
    /// 在 SDK 数据库锁内查询，返回不可变结果并排除暂缓的特殊业务。
    func search(_ query: String, userUID: String) async throws -> [GlobalSearchResult] {
        let showAssistant = UserRoleAuthorityStore.shared.current?.allows("isShowFileAssistant") == true
        let sessionID = LoginSessionService.shared.maintenanceSessionID
        let license = OSSNavigationStore.shared.lastUsableLiceseId()
        guard sessionID != nil, let license else { throw CancellationError() }
        let results = try await Task.detached {
            let sdk = NoaIMSDKManager.sharedTool()
            objc_sync_enter(sdk)
            defer { objc_sync_exit(sdk) }
            guard sdk.myUserID() == userUID, sdk.mySsoInfo() == license,
                  sdk.isUserDatabaseReady() else { throw UserSessionError.databaseNotReady }
            var results: [GlobalSearchResult] = []
            let friends = sdk.toolSearchMyFriend(with: query) as? [LingIMFriendModel] ?? []
            for friend in friends {
                guard let uid = friend.friendUserUID, !uid.isEmpty,
                      friend.userType == 0 || (uid == "100002" && showAssistant) else { continue }
                results.append(GlobalSearchResult(id: "friend.\(uid)", kind: .friend, peerID: uid,
                    title: friend.disableStatus == 4 ? "账号已注销" : (friend.showName ?? friend.nickname ?? uid),
                    detail: friend.userName ?? "", avatar: friend.disableStatus == 4 ? "" : (friend.avatar ?? ""), messageID: nil, date: nil))
            }
            let foundGroups: [LingIMGroupModel]? = sdk.toolSearchMyGroup(with: query)
            for group in foundGroups ?? [] where group.groupStatus == 1 && group.leaveGroupStatus == 0 {
                let identifier: String? = group.groupId
                let name: String? = group.groupName
                let avatar: String? = group.groupAvatar
                guard let id = identifier, !id.isEmpty else { continue }
                results.append(GlobalSearchResult(id: "group.\(id)", kind: .group, peerID: id,
                    title: name.flatMap { $0.isEmpty ? nil : $0 } ?? id, detail: "群聊", avatar: avatar ?? "", messageID: nil, date: nil))
            }
            let foundMessages: [NoaIMChatMessageModel]? = sdk.toolSearchMessage(with: query)
            var seen: Set<String> = []
            for message in foundMessages ?? [] {
                let type = Int(message.chatType.rawValue)
                guard let peer = GlobalSearchMessageIdentity.peer(status: message.messageStatus, chatType: type,
                    from: message.fromID ?? "", to: message.toID ?? "", userUID: userUID),
                    peer != "100002" || showAssistant else { continue }
                let session: LingIMSessionModel? = sdk.toolCheckMySession(with: peer)
                if let session, Int(session.sessionType.rawValue) != type + 1 { continue }
                let messageID = message.serviceMsgID?.isEmpty == false ? message.serviceMsgID : message.msgID
                guard let messageID, !messageID.isEmpty, seen.insert("\(peer).\(messageID)").inserted else { continue }
                let friend = type == 0 ? sdk.toolCheckMyFriend(with: peer) : nil
                let group = type == 1 ? sdk.toolCheckMyGroup(with: peer) : nil
                if type == 1 {
                    guard group?.groupStatus == 1, group?.leaveGroupStatus == 0 else { continue }
                } else {
                    guard friend != nil || session != nil else { continue }
                    if let friend, friend.userType != 0 && !(peer == "100002" && showAssistant) { continue }
                }
                let title = type == 1 ? (group?.groupName ?? peer) : (friend?.showName ?? peer)
                let preview = SDKChatMessageMapper.record(message, userUID: userUID).displayText
                results.append(GlobalSearchResult(id: "message.\(peer).\(messageID)", kind: type == 1 ? .groupMessage : .singleMessage,
                    peerID: peer, title: title, detail: preview,
                    avatar: type == 1 ? (group?.groupAvatar ?? "") : (friend?.avatar ?? ""), messageID: messageID,
                    date: Date(timeIntervalSince1970: TimeInterval(message.sendTime) / 1000)))
            }
            return results
        }.value
        guard LoginSessionService.shared.maintenanceSessionID == sessionID,
              OSSNavigationStore.shared.lastUsableLiceseId() == license else { throw CancellationError() }
        return results
    }
}

/// SDK全文检索仍可能返回删除/撤回正文，返回前核对状态及本人单聊方向。
nonisolated enum GlobalSearchMessageIdentity {
    static func peer(status: Int, chatType: Int, from: String, to: String, userUID: String) -> String? {
        guard status == 1, !userUID.isEmpty, !from.isEmpty, !to.isEmpty else { return nil }
        if chatType == 1 { return to }
        guard chatType == 0 else { return nil }
        if from == userUID { return to }
        return to == userUID ? from : nil
    }
}
