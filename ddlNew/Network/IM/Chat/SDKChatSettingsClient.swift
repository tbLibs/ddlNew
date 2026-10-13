//
//  SDKChatSettingsClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore

/// 群管理与聊天消息共用身份守卫，群详情DTO独立于通讯录群列表。
@MainActor final class SDKChatSettingsClient: ChatSettingsClient {
    private let client = SDKChatClient(validSession: { ChatRuntime.shared.isCurrent($0) })
    private var context: ChatContext?
    private var changed: (@MainActor () -> Void)?
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }

    /// 设置页拥有独立SDK等待，关闭不会取消聊天Store的代理。
    private func bind(_ context: ChatContext) {
        if self.context != context { client.observe(context: context, onEvent: { [weak self] event in switch event { case .permissionsChanged, .memberMetadataChanged: self?.changed?(); default: break } }); self.context = context }
    }

    /// 群详情和成员来自真实接口，角色只使用当前服务端返回值。
    func load(context: ChatContext) async throws -> ChatSettingsSnapshot {
        bind(context); try client.validate(context)
        var group: ChatGroupDetail?
        if context.route.kind == .group {
            let params: [AnyHashable: Any] = ["groupId": context.route.id, "userUid": context.userUID]
            let json = try await client.request(context: context) { success, failure in self.sdk.getGroupInfo(with: params, onSuccess: success, onFailure: failure) }
            client.updateGroupCache(json, context: context)
            let role = integer(json["userGroupRole"])
            group = ChatGroupDetail(id: context.route.id, name: json["groupName"] as? String ?? context.route.title,
                avatar: json["groupAvatar"] as? String ?? "", role: role,
                isActive: integer(json["groupStatus"]) == 1 && boolean(json["userInGroup"]),
                nickname: json["nicknameInGroup"] as? String ?? "", isAllMuted: boolean(json["isGroupChat"]),
                isPrivateChat: boolean(json["isPrivateChat"]), requiresApproval: boolean(json["isNeedVerify"]),
                historyVisible: boolean(json["isShowHistory"]), qrVisible: boolean(json["isShowQrCode"]),
                remindEnabled: integer(json["isMessageInform"]) == 1, memberCount: integer(json["memberCount"]), isNetCall: boolean(json["isNetCall"]))
            if group?.isActive == false { return ChatSettingsSnapshot(isPinned: false, isMuted: false, canClear: false, group: group) }
            var members: [String: ChatGroupMember] = [:]
            var page = 1
            while true {
                let data = try await client.request(context: context) { success, failure in
                    self.sdk.getGroupMemberList(with: NSMutableDictionary(dictionary: ["groupId": context.route.id, "userUid": context.userUID, "pageSize": 100, "pageNumber": page, "pageStart": (page - 1) * 100]), onSuccess: success, onFailure: failure)
                }
                let rows = data["rows"] as? [[String: Any]] ?? []
                let before = members.count
                for row in rows {
                    guard let id = row["userUid"] as? String, !id.isEmpty else { continue }
                    let remark = row["remarks"] as? String ?? ""
                    let groupNick = row["nicknameInGroup"] as? String ?? ""
                    updateMemberCache(row, context: context)
                    members[id] = ChatGroupMember(id: id, name: !remark.isEmpty ? remark : !groupNick.isEmpty ? groupNick : row["userNickname"] as? String ?? row["nickname"] as? String ?? id,
                        avatar: row["userAvatar"] as? String ?? row["avatar"] as? String ?? "", role: integer(row["role"]), isDeleted: integer(row["disableStatus"]) == 4)
                }
                if rows.count < 100 || before == members.count { break }; page += 1
            }
            try client.validate(context)
            group?.members = members.values.sorted { $0.role == $1.role ? $0.name.localizedCompare($1.name) == .orderedAscending : $0.role > $1.role }
            group?.membersSyncReady = true
            ChatRuntime.shared.updatedGroupMembers(group?.members ?? [], context: context)
            let mute = try await client.request(context: context) { success, failure in self.sdk.groupGetUserNotalkState(with: NSMutableDictionary(dictionary: ["groupId": context.route.id, "userUid": context.userUID]), onSuccess: success, onFailure: failure) }
            group?.isPersonallyMuted = integer(mute["isGroupForbid"]) == 1
            group?.isAllMuted = integer(mute["isGroupChat"]) == 1
            if [1, 2].contains(role) {
                let result = try await client.request(context: context) { success, failure in self.sdk.groupGetNotalkList(with: NSMutableDictionary(dictionary: ["groupId": context.route.id, "userUid": context.userUID]), onSuccess: success, onFailure: failure) }
                let rows = result["_value"] as? [[String: Any]] ?? result["rows"] as? [[String: Any]] ?? []
                group?.bannedMembers = rows.compactMap { row -> ChatGroupBanRecord? in
                    guard let id = row["forbidUserUid"] as? String, !id.isEmpty else { return nil }
                    return ChatGroupBanRecord(id: id, name: row["forbidUserNickName"] as? String ?? members[id]?.name ?? id, avatar: row["forbidUserIcon"] as? String ?? "", expires: row["expireTime"] as? String ?? (row["expireTime"] as? NSNumber)?.stringValue ?? "", updatedAt: row["updateTime"] as? String ?? "")
                }
            }
        }
        try client.validate(context)
        let session: LingIMSessionModel? = sdk.toolCheckMySession(with: context.route.id)
        return ChatSettingsSnapshot(isPinned: session?.sessionTop ?? false, isMuted: session?.sessionNoDisturb ?? false,
            canClear: UserRoleAuthorityStore.shared.current?.allows("deleteMessage") == true, group: group)
    }

    /// 不直接乐观更新开关，真实回执后SDK缓存会话字段一起更新。
    func setConversation(context: ChatContext, pinned: Bool?, muted: Bool?) async throws {
        bind(context); try client.validate(context)
        guard context.route.id != "100002" || muted == nil else { throw ChatClientError.permission("文件助手不支持免打扰") }
        let group = context.route.kind == .group
        var params: [String: Any] = ["userUid": context.userUID, group ? "groupId" : "friendUserUid": context.route.id]
        if let pinned {
            params["status"] = pinned ? 1 : 0
            _ = try await client.request(context: context) { success, failure in
                if group { self.sdk.groupConversationTop(NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure) }
                else { self.sdk.singleConversationTop(NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure) }
            }
        }
        if let muted {
            params["status"] = muted ? 1 : 0
            _ = try await client.request(context: context) { success, failure in
                if group { self.sdk.groupConversationPromt(NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure) }
                else { self.sdk.singleConversationPromt(NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure) }
            }
        }
        try client.validate(context)
        let cachedSession: LingIMSessionModel? = sdk.toolCheckMySession(with: context.route.id)
        if let session = cachedSession {
            if let pinned { session.sessionTop = pinned }; if let muted { session.sessionNoDisturb = muted }
            sdk.toolUpdateSession(with: session)
        }
    }

    /// 清空后只删对应聊天SDK历史，接口失败不清缓存。
    func clear(context: ChatContext) async throws {
        bind(context); try client.validate(context)
        guard UserRoleAuthorityStore.shared.current?.allows("deleteMessage") == true else { throw ChatClientError.permission("当前账号不允许清空聊天记录") }
        _ = try await client.request(context: context) { success, failure in self.sdk.clearChatMessageHistory(NSMutableDictionary(dictionary: ["chatType": context.route.kind == .group ? 1 : 0, "userUid": context.userUID, "receiveId": context.route.id]), onSuccess: success, onFailure: failure) }
        try client.validate(context)
        ChatRuntime.shared.markCleared(context)
        guard sdk.toolDeleteAllChatMessage(with: context.route.id) else { throw ChatClientError.unavailable("服务器已受理清空，本地清理失败，请重新进入聊天") }
        try ChatMediaPreviewStore.clearCache(context: context)
    }

    /// 每项群操作真实刷新角色后按独立参数提交，群主退出必须先转让。
    func groupAction(_ action: ChatGroupAction, context: ChatContext) async throws {
        guard let detail = try await load(context: context).group,
              ChatGroupPolicy.permits(action, detail: detail, userUID: context.userUID) else { throw ChatClientError.permission("群权限已变化，请刷新后重试") }
        var params: [String: Any] = ["groupId": context.route.id, "userUid": context.userUID]
        _ = try await client.request(context: context) { success, failure in
            switch action {
            case .rename(let value): params["groupName"] = value.trimmingCharacters(in: .whitespacesAndNewlines); self.sdk.changeGroupName(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .nickname(let value):
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.utf16.count <= 30 else { failure(-1, "昵称最多30字", nil); return }
                params["groupNickname"] = trimmed.isEmpty ? UserSessionStore.shared.currentUser?.nickname ?? "" : trimmed
                self.sdk.groupMyNickname(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .avatar(let value): params["avatar"] = value; self.sdk.changeGroupAvatar(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .invite(let members, let reason):
                params["groupMemberParams"] = members.map { ["userUid": $0.id, "nickName": $0.name] }; params["inviteDesc"] = reason.trimmingCharacters(in: .whitespacesAndNewlines)
                self.sdk.groupInviteFriend(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .remove(let ids, let delete): params["groupMemberUidList"] = ids; params["delMemberMsg"] = delete ? 1 : 0; self.sdk.groupRemoveMember(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .muteAll(let enabled): params["operationType"] = enabled ? "1" : "0"; self.sdk.groupSetNotalkAll(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .muteMembers(let ids, let minutes): params["forbidUidList"] = ids; params["expireTime"] = minutes; params["operationType"] = minutes == 0 ? 0 : 1; self.sdk.groupSetNotalkMember(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .setManagers(let ids, let enabled): params["groupMemberUidList"] = ids; params["operationType"] = enabled ? "1" : "2"; self.sdk.groupSetGroupManager(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .transferOwner(let id): params["ownerUid"] = id; self.sdk.groupChangeGroupOwner(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .privateChat(let value): params["status"] = value ? "1" : "0"; self.sdk.groupSetPrivateChatStatus(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .approval(let value): params["status"] = value ? "1" : "0"; self.sdk.groupSetJoinGroupStatus(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .history(let value): params["status"] = value ? 1 : 0; self.sdk.groupNewMemberCheckHistoryStatus(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .qr(let value): params["isShowQrCode"] = value ? 1 : 0; self.sdk.groupUpdateIsShowQrCode(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .remind(let value): params["status"] = value ? 1 : 0; self.sdk.groupUpdateGroupRemindSwitchStatus(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .prohibitCalls(let value): params["status"] = value ? 1 : 0; self.sdk.groupUpdateAudioAndVideoCallStatus(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .leave: self.sdk.groupQuit(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            case .dissolve: self.sdk.groupDissolutionGroup(with: NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure)
            }
        }
        try client.validate(context)
        if case .remove(let ids, let deleteMessages) = action {
            for id in ids { sdk.imSdkDeleteGroupMember(with: id, groupID: context.route.id); if deleteMessages { sdk.toolDeleteGroupMemberAllSendMessage(with: id, groupID: context.route.id) } }
            if deleteMessages { ChatRuntime.shared.removedMemberMessages(ids, context: context); try? ChatMediaPreviewStore.clearCache(context: context) }
        }
        if action == .leave || action == .dissolve {
            sdk.toolDeleteMyGroup(with: context.route.id); sdk.toolDeleteAllChatMessage(with: context.route.id); ChatRuntime.shared.closeConversation(id: context.route.id)
        }
    }

    /// 刷新真实成员表，让SDK消息映射的备注、群昵称和角色优先级与服务端一致。
    private func updateMemberCache(_ row: [String: Any], context: ChatContext) {
        guard let id = row["userUid"] as? String, !id.isEmpty else { return }
        let model = (sdk.imSdkCheckGroupMember(with: id, groupID: context.route.id) as LingIMGroupMemberModel?) ?? LingIMGroupMemberModel()
        model.userUid = id; model.role = integer(row["role"]); model.disableStatus = integer(row["disableStatus"])
        model.nicknameInGroup = row["nicknameInGroup"] as? String ?? ""; model.remarks = row["remarks"] as? String ?? model.remarks
        model.userNickname = row["userNickname"] as? String ?? row["nickname"] as? String ?? model.userNickname
        model.userAvatar = row["userAvatar"] as? String ?? row["avatar"] as? String ?? model.userAvatar
        model.showName = !(model.remarks ?? "").isEmpty ? model.remarks : !(model.nicknameInGroup ?? "").isEmpty ? model.nicknameInGroup : model.userNickname
        sdk.imSdkInsertOrUpdateGroupMember(model, groupID: context.route.id)
    }

    /// 动态群事件向设置页回读请求转发，提交仍需重新校验服务端权限。
    func observe(_ changed: @escaping @MainActor () -> Void) { self.changed = changed }

    /// 服务端混合数字字符串按字段合同归一化。
    private func integer(_ value: Any?) -> Int { (value as? NSNumber)?.intValue ?? Int(value as? String ?? "") ?? 0 }
    /// 开关接受服务端布尔与0/1字符串。
    private func boolean(_ value: Any?) -> Bool { (value as? NSNumber)?.boolValue ?? ["true", "1"].contains((value as? String ?? "").lowercased()) }
    /// 关闭设置页释放所有旧回调资格。
    func close() { client.stop(); context = nil; changed = nil }
}
