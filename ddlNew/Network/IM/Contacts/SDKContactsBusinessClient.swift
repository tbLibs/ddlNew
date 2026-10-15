//
//  SDKContactsBusinessClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore
import ObjectMapper
import ObjectiveC

/// 好友写操作均复用SDK验签与请求会话隔离，不自行拼HTTP。
@MainActor final class SDKContactsBusinessClient: ContactBusinessClient {
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }
    private var generation = UUID()
    private var delegate: SDKContactsBusinessDelegate?
    private var currentIdentity: ContactsIdentity?
    private var waiters: [UUID: ContactBusinessRequestWaiter<Data>] = [:]

    /// AUTH前观察申请与分组变化，迟到代理通过客户端轮次过滤。
    func observe(_ onChange: @escaping @MainActor () -> Void) {
        let revision = generation
        let delegate = SDKContactsBusinessDelegate(change: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.generation == revision else { return }
                onChange()
            }
        }, removed: { [weak self] friendUID in
            Task { @MainActor [weak self] in
                guard let self, self.generation == revision, let identity = self.currentIdentity else { return }
                _ = ContactProfileRequestGate.shared.begin(userUID: identity.userUID, license: identity.license, friendUID: friendUID)
                onChange()
            }
        })
        self.delegate = delegate; sdk.addUserDelegate(delegate)
    }

    /// 退出时释放代理并撤销所有SDK业务回调归属。
    func reset() {
        generation = UUID(); currentIdentity = nil; ContactProfileRequestGate.shared.reset()
        for waiter in waiters.values { waiter.cancel() }; waiters = [:]
        if let delegate { sdk.removeUserDelegate(delegate) }; delegate = nil
    }

    /// 启动与回执后核对UID、俱乐部、数据库与客户端会话轮次。
    private func validate(_ identity: ContactsIdentity, revision: UUID) throws {
        guard generation == revision, sdk.myUserID() == identity.userUID, sdk.isUserDatabaseReady(),
              OSSNavigationStore.shared.lastUsableLiceseId() == identity.license,
              currentIdentity == identity else { throw ContactBusinessError.staleSession }
    }

    /// 将有界SDK回调转成async，收到回执后再转换值快照。
    private func call(_ identity: ContactsIdentity, _ start: (@escaping LingIMSuccessCallback, @escaping LingIMFailureCallback) -> Void) async throws -> Any {
        let revision = generation
        try validate(identity, revision: revision)
        let id = UUID(), waiter = ContactBusinessRequestWaiter<Data>()
        waiters[id] = waiter; defer { waiters.removeValue(forKey: id) }
        let bytes = try await waiter.run {
            start({ data, _ in
                let bytes = try? JSONSerialization.data(withJSONObject: data ?? NSNull(), options: [.fragmentsAllowed])
                Task { @MainActor in
                    if let bytes { waiter.finish(.success(bytes)) }
                    else { waiter.finish(.failure(ContactBusinessError.malformedResponse)) }
                }
            }, { code, message, _ in
                Task { @MainActor in waiter.finish(.failure(ContactBusinessError.server(code: code, message: message ?? ""))) }
            })
        }
        try validate(identity, revision: revision)
        return try JSONSerialization.jsonObject(with: bytes, options: [.fragmentsAllowed])
    }

    /// 只回写本轮账号的申请角标，其他客户端不会清空新用户计数。
    func updateUnreadCount(_ count: Int, identity: ContactsIdentity) {
        guard (try? validate(identity, revision: generation)) != nil else { return }
        sdk.toolUpdateFriendApplyCount(max(0, count))
    }

    /// 根据已确认SDK方法和旧参数执行业务操作，禁止猜测新协议。
    func request(_ operation: ContactBusinessOperation, identity: ContactsIdentity) async throws -> ContactBusinessResponse {
        if currentIdentity == nil { currentIdentity = identity }
        try validate(identity, revision: generation)
        let params: NSMutableDictionary = ["userUid": identity.userUID]
        var response = ContactBusinessResponse()
        switch operation {
        case .blackState(let id):
            params["friendUserUid"] = id
            response.isBlack = try ContactBusinessPayload.blackFlag(await call(identity) { sdk.getUserBlackState(with: params, onSuccess: $0, onFailure: $1) })
        case .blacklist:
            let data = try await call(identity) { sdk.getBlackListFromServer(with: params, onSuccess: $0, onFailure: $1) }
            response.contacts = try ContactBusinessPayload.searchContacts(from: data)
        case .setBlack(let id, let blocked):
            guard !id.isEmpty, id != identity.userUID, id != "100002" else { throw ContactBusinessError.invalidInput("不能对该用户操作黑名单") }
            params["friendUserUid"] = id; params["status"] = blocked ? 1 : 0
            response.success = try ContactBusinessPayload.blackFlag(await call(identity) { success, failure in
                if blocked { sdk.addUserToBlackList(with: params, onSuccess: success, onFailure: failure) }
                else { sdk.removeUserFromBlackList(with: params, onSuccess: success, onFailure: failure) }
            })
        case .search(let text):
            // 旧精确账号检索仅传userName，当前身份由SDK认证和回执轮次校验，不追加目标UID过滤。
            params.removeObject(forKey: "userUid")
            params["userName"] = text
            let data = try await call(identity) { sdk.userSearch(with: params, onSuccess: $0, onFailure: $1) }
            response.contacts = try ContactBusinessPayload.searchContacts(from: data)
        case .profile(let id), .profileAfterAcceptance(let id):
            let profileVersion = ContactProfileRequestGate.shared.begin(userUID: identity.userUID, license: identity.license, friendUID: id)
            defer { ContactProfileRequestGate.shared.finish(profileVersion, userUID: identity.userUID, license: identity.license, friendUID: id) }
            params["friendUserUid"] = id
            let relation = try await call(identity) { sdk.checkMyFriend(with: params, onSuccess: $0, onFailure: $1) }
            guard let isFriend = relation as? NSNumber else { throw ContactBusinessError.malformedResponse }
            response.isFriend = isFriend.boolValue
            let data: Any
            if response.isFriend { data = try await call(identity) { sdk.getFriendInfo(with: params, onSuccess: $0, onFailure: $1) } }
            else {
                let userParams: NSMutableDictionary = ["userUid": id]
                data = try await call(identity) { sdk.getUserInfo(with: userParams, onSuccess: $0, onFailure: $1) }
            }
            let cached: ContactRecord?
            if let friend = sdk.toolCheckMyFriend(with: id) {
                cached = ContactRecord(id: id, account: friend.userName ?? "", nickname: friend.nickname ?? "", remarks: friend.remarks ?? "", description: friend.descRemark ?? "", avatar: friend.avatar ?? "", isOnline: friend.onlineStatus, disableStatus: friend.disableStatus, userType: friend.userType, roleID: friend.roleId)
            } else { cached = nil }
            guard let fields = data as? [String: Any], let profile = Mapper<ContactBusinessPayload>().map(JSON: fields)?.contact(fallbackID: id, cached: cached), profile.id == id else { throw ContactBusinessError.malformedResponse }
            guard ContactProfileRequestGate.shared.accepts(profileVersion, userUID: identity.userUID, license: identity.license, friendUID: id) else { throw ContactBusinessError.staleSession }
            response.profile = profile
            if response.isFriend {
                let latestRelation = try boolean(await call(identity) { sdk.checkMyFriend(with: params, onSuccess: $0, onFailure: $1) })
                guard ContactProfileRequestGate.shared.accepts(profileVersion, userUID: identity.userUID, license: identity.license, friendUID: id) else { throw ContactBusinessError.staleSession }
                response.isFriend = latestRelation
                if latestRelation {
                    let mayCreate: Bool
                    if case .profileAfterAcceptance = operation { mayCreate = true } else { mayCreate = false }
                    try persist(profile, identity: identity, addIfMissing: mayCreate, profileVersion: profileVersion)
                }
            }
        case .groupAccess(let groupID):
            let groupParams: [AnyHashable: Any] = ["groupId": groupID, "userUid": identity.userUID]
            let data = try await call(identity) { sdk.getGroupInfo(with: groupParams, onSuccess: $0, onFailure: $1) }
            let cachedGroup: LingIMGroupModel? = sdk.toolCheckMyGroup(with: groupID)
            guard let group = cachedGroup, group.leaveGroupStatus == 0, group.groupStatus == 1,
                  let fields = data as? [String: Any], let mapped = Mapper<ContactBusinessPayload>().map(JSON: fields) else { return response }
            let role = mapped.integer("userGroupRole", default: -1)
            guard [0, 1, 2].contains(role), mapped.integer("groupStatus", default: 1) == 1,
                  fields["userInGroup"] == nil || mapped.flag("userInGroup") else { return response }
            response.canAccessProfile = role > 0 || !mapped.flag("isPrivateChat") || UserRoleAuthorityStore.shared.current?.allows("groupSecurity") == true
        case .groupNickname(let groupID, let targetUID):
            // 此接口userUid是被查询的群成员，不是当前操作者；请求所有权仍由identity检查。
            let nicknameParams: NSMutableDictionary = ["groupId": groupID, "userUid": targetUID]
            let data = try await call(identity) { sdk.groupGetUserNicKName(with: nicknameParams, onSuccess: $0, onFailure: $1) }
            guard let fields = data as? [String: Any], let value = fields["nicknameInGroup"], value is String || value is NSNull else { throw ContactBusinessError.malformedResponse }
            response.groupNickname = value as? String ?? ""
        case .applications(let page):
            params["pageNumber"] = page; params["pageSize"] = 20; params["pageStart"] = (page - 1) * 20
            let data = try await call(identity) { sdk.getFriendApplyListFromServer(with: params, onSuccess: $0, onFailure: $1) }
            guard let fields = data as? [String: Any], let rows = fields["rows"] as? [[String: Any]] else { throw ContactBusinessError.malformedResponse }
            response.applications = rows.compactMap { Mapper<ContactBusinessPayload>().map(JSON: $0)?.application() }
            response.hasMore = rows.count == 20
        case .unreadApplications:
            let data = try await call(identity) { sdk.getFriendSyncReqList(with: params, onSuccess: $0, onFailure: $1) }
            guard let fields = data as? [String: Any], let rows = fields["records"] as? [[String: Any]] else { throw ContactBusinessError.malformedResponse }
            for row in rows {
                guard let mapped = Mapper<ContactBusinessPayload>().map(JSON: row), !mapped.text("hashKey").isEmpty else { continue }
                response.unreadVersions[mapped.text("hashKey")] = mapped.text("latestUpdateTime")
            }
        case .roleLabels:
            let data = try await call(identity) { sdk.imGetRoleConfigInfo(with: nil, onSuccess: $0, onFailure: $1) }
            guard let rows = data as? [[String: Any]] else { throw ContactBusinessError.malformedResponse }
            let chinese = Locale.preferredLanguages.first?.hasPrefix("zh") == true
            for row in rows {
                guard let mapped = Mapper<ContactBusinessPayload>().map(JSON: row), mapped.flag("showRoleName") else { continue }
                let label = chinese ? mapped.text("roleName") : mapped.text("enName")
                if !label.isEmpty { response.roleLabels[mapped.integer("roleId")] = label }
            }
        case .apply(let id):
            params["friendUserUid"] = id
            let relation = try await call(identity) { sdk.checkMyFriend(with: params, onSuccess: $0, onFailure: $1) }
            guard let friend = relation as? NSNumber else { throw ContactBusinessError.malformedResponse }
            guard !friend.boolValue else { throw ContactBusinessError.invalidInput("该用户已经是你的好友") }
            try validateAllowedFriend(id, identity: identity, adding: true)
            response.success = try boolean(await call(identity) { sdk.addContact(with: params, onSuccess: $0, onFailure: $1) })
        case .accept(let id):
            params["friendUserUid"] = id
            let alreadyFriend = try boolean(await call(identity) { sdk.checkMyFriend(with: params, onSuccess: $0, onFailure: $1) })
            if !alreadyFriend {
                try validateAllowedFriend(id, identity: identity, adding: true)
                response.success = try boolean(await call(identity) { sdk.confirmFriendApply(with: params, onSuccess: $0, onFailure: $1) })
            }
        case .setRemark(let id, let remark, let description):
            try validateAllowedFriend(id, identity: identity, adding: false)
            params["friendUserUid"] = id; params["remark"] = remark; params["descRemark"] = description
            response.success = try boolean(await call(identity) { sdk.friendSetFriendRemarkAndDes(with: params, onSuccess: $0, onFailure: $1) })
            if response.success {
                response.profile = try persistSavedRemark(id: id, remark: remark, description: description, identity: identity)
                response.isFriend = true
            }
        case .deleteFriend(let id):
            try validateAllowedFriend(id, identity: identity, adding: false)
            params["friendUserUid"] = id
            response.success = try boolean(await call(identity) { sdk.deleteContact(with: params, onSuccess: $0, onFailure: $1) })
            if response.success {
                let deleteParams: NSMutableDictionary = ["userUid": identity.userUID, "peerUid": id, "dialogType": 0]
                do {
                    let cleared = try boolean(await call(identity) { sdk.deleteServerConversation(deleteParams, onSuccess: $0, onFailure: $1) })
                    guard cleared else { throw ContactBusinessError.invalidInput("聊天记录清理未完成") }
                    let cachedSession: LingIMSessionModel? = sdk.toolCheckMySession(with: id)
                    if let session = cachedSession, !sdk.toolDeleteSessionModel(with: session, andDeleteAllChatModel: true) { throw ContactBusinessError.invalidInput("本机聊天记录清理失败") }
                    ChatRuntime.shared.closeConversation(id: id)
                } catch { throw ContactBusinessError.invalidInput("好友已删除，但聊天记录清理失败。请在聊天设置中重试。") }
            }
        case .groups:
            let data = try await call(identity) { sdk.getFriendGroupList(with: params, onSuccess: $0, onFailure: $1) }
            guard let rows = data as? [[String: Any]] else { throw ContactBusinessError.malformedResponse }
            objc_sync_enter(sdk)
            defer { objc_sync_exit(sdk) }
            try validate(identity, revision: generation)
            let returnedIDs = Set(rows.compactMap { Mapper<ContactBusinessPayload>().map(JSON: $0)?.text("ugUuid") }.filter { !$0.isEmpty })
            let cachedGroups: [LingIMFriendGroupModel]? = sdk.toolGetMyFriendGroupList()
            guard let cachedGroups else { throw ContactBusinessError.invalidInput("好友分组缓存读取失败，请刷新重试") }
            for group in cachedGroups where !returnedIDs.contains(group.ugUuid ?? "") { _ = sdk.toolDeleteMyFriendGroup(with: group.ugUuid ?? "") }
            for row in rows {
                guard let mapped = Mapper<ContactBusinessPayload>().map(JSON: row), !mapped.text("ugUuid").isEmpty else { continue }
                if mapped.integer("delFlag") == 1 { _ = sdk.toolDeleteMyFriendGroup(with: mapped.text("ugUuid")) }
                else {
                    let group = LingIMFriendGroupModel()
                    group.ugUuid = mapped.text("ugUuid"); group.ugName = mapped.text("ugName")
                    group.ugOrder = mapped.integer("ugOrder"); group.ugType = mapped.integer("ugType")
                    _ = sdk.toolUpdateMyFriendGroup(with: group)
                }
            }
            response.groups = try loadGroups()
        case .createGroup(let name):
            params["ugName"] = name
            let data = try await call(identity) { sdk.createFriendGroup(with: params, onSuccess: $0, onFailure: $1) }
            response.success = try mutationResult(data)
        case .renameGroup(let id, let name):
            params["ugUuid"] = id; params["ugName"] = name
            response.success = try mutationResult(await call(identity) { sdk.updateFriendGroup(with: params, onSuccess: $0, onFailure: $1) })
        case .reorderGroup(let id, let order):
            params["ugUuid"] = id; params["ugOrder"] = order
            response.success = try mutationResult(await call(identity) { sdk.updateFriendGroup(with: params, onSuccess: $0, onFailure: $1) })
        case .deleteGroup(let id):
            guard try loadGroups().contains(where: { $0.id == id && !$0.isDefault }) else { throw ContactBusinessError.invalidInput("默认分组不可删除") }
            params["ugUuid"] = id
            response.success = try mutationResult(await call(identity) { sdk.deleteFriendGroup(with: params, onSuccess: $0, onFailure: $1) })
        case .moveFriend(let id, let groupID):
            try validateAllowedFriend(id, identity: identity, adding: false)
            params["uguUserUid"] = id; params["uguUgUuid"] = groupID
            response.success = try mutationResult(await call(identity) { sdk.updateFriendForFriendGroup(with: params, onSuccess: $0, onFailure: $1) })
        case .qrCode(let groupID):
            if let groupID {
                let currentGroup: LingIMGroupModel? = sdk.toolCheckMyGroup(with: groupID)
                guard let group = currentGroup, group.leaveGroupStatus == 0, group.groupStatus == 1, [1, 2].contains(group.userGroupRole) || group.isShowQrCode else { throw ContactBusinessError.invalidInput("该群当前不允许展示二维码") }
                let json = try JSONSerialization.data(withJSONObject: ["groupId": groupID])
                params["content"] = String(data: json, encoding: .utf8) ?? ""; params["type"] = 2
            } else { params["content"] = ""; params["type"] = 1 }
            let data = try await call(identity) { sdk.userGetCreatQrcodeContent(with: params, onSuccess: $0, onFailure: $1) }
            guard let fields = data as? [String: Any], let mapped = Mapper<ContactBusinessPayload>().map(JSON: fields), !mapped.text("content").isEmpty else { throw ContactBusinessError.malformedResponse }
            response.qrCode = mapped.text("content"); response.expiry = mapped.text("expireTime")
        case .decodeQR(let content):
            params["content"] = content
            let data = try await call(identity) { sdk.userGetTransformQrcodeContent(with: params, onSuccess: $0, onFailure: $1) }
            response.qrTarget = try decodeQR(data)
        case .joinGroup(let id, let inviter, let reason):
            params["groupId"] = id; params["inviteUserId"] = inviter; params["inviteType"] = 4
            params["adviceStatus"] = 0; params["topStatus"] = 0; params["applyDesc"] = reason
            response.success = try boolean(await call(identity) { sdk.userApplyJoinGroup(withData: params, onSuccess: $0, onFailure: $1) })
        }
        return response
    }

    /// 仅接受实际布尔回执，不能将任意非空响应当成功。
    private func boolean(_ data: Any) throws -> Bool {
        guard let number = data as? NSNumber else { throw ContactBusinessError.malformedResponse }; return number.boolValue
    }

    /// 分组接口旧实现可返回布尔、分组字典或空数据，HTTP业务成功仍需随后回读。
    private func mutationResult(_ data: Any) throws -> Bool {
        if let number = data as? NSNumber { return number.boolValue }
        if data is NSNull || data is [String: Any] { return true }
        throw ContactBusinessError.malformedResponse
    }

    /// 写操作前检查实际好友是否仍存在以及注销状态。
    private func validateAllowedFriend(_ id: String, identity: ContactsIdentity, adding: Bool) throws {
        guard id != identity.userUID else { throw ContactBusinessError.invalidInput("不能对自己执行该操作") }
        if adding {
            guard UserRoleAuthorityStore.shared.current?.allows("allowAddFriend") == true else { throw ContactBusinessError.invalidInput("当前账号无添加好友权限") }
        } else {
            guard let friend = sdk.toolCheckMyFriend(with: id), friend.disableStatus != 4 else { throw ContactBusinessError.invalidInput("好友关系已变化，请刷新资料") }
        }
    }

    /// 服务器确认保存后立即写入SDK好友缓存，避免紧接着的旧资料回读恢复旧备注。
    private func persistSavedRemark(id: String, remark: String, description: String, identity: ContactsIdentity) throws -> ContactRecord {
        let sdk = self.sdk
        objc_sync_enter(sdk); defer { objc_sync_exit(sdk) }
        try validate(identity, revision: generation)
        guard let friend = sdk.toolCheckMyFriend(with: id), friend.disableStatus != 4 else {
            throw ContactBusinessError.invalidInput("好友关系已变化，请刷新资料")
        }
        // 撤销保存前的资料读取，旧请求不能迟到覆盖本次已确认修改。
        let version = ContactProfileRequestGate.shared.begin(userUID: identity.userUID, license: identity.license, friendUID: id)
        defer { ContactProfileRequestGate.shared.finish(version, userUID: identity.userUID, license: identity.license, friendUID: id) }
        friend.remarks = remark; friend.descRemark = description
        friend.remarksPinyin = ContactSorter.searchPinyin(for: remark)
        friend.showName = remark.isEmpty ? friend.nickname : remark
        guard sdk.toolUpdateMyFriend(with: friend) else {
            throw ContactBusinessError.invalidInput("备注已保存，但本机缓存更新失败，请刷新重试")
        }
        return ContactRecord(id: id, account: friend.userName ?? "", nickname: friend.nickname ?? "",
                             remarks: remark, description: description, avatar: friend.avatar ?? "",
                             isOnline: friend.onlineStatus, disableStatus: friend.disableStatus, userType: friend.userType,
                             nicknamePinyin: friend.nicknamePinyin ?? "", remarksPinyin: friend.remarksPinyin ?? "", roleID: friend.roleId)
    }

    /// 在数据库共用锁内写入完整资料，避免写入其他登录会话。
    private func persist(_ record: ContactRecord, identity: ContactsIdentity, addIfMissing: Bool, profileVersion: UUID) throws {
        objc_sync_enter(sdk); defer { objc_sync_exit(sdk) }
        try validate(identity, revision: generation)
        guard ContactProfileRequestGate.shared.accepts(profileVersion, userUID: identity.userUID, license: identity.license, friendUID: record.id) else { throw ContactBusinessError.staleSession }
        let existing = sdk.toolCheckMyFriend(with: record.id)
        guard existing != nil || addIfMissing else { return }
        let friend = existing ?? LingIMFriendModel()
        friend.friendUserUID = record.id; friend.userName = record.account; friend.nickname = record.nickname
        friend.nicknamePinyin = record.nicknamePinyin; friend.remarks = record.remarks; friend.remarksPinyin = record.remarksPinyin
        friend.descRemark = record.description; friend.avatar = record.avatar; friend.disableStatus = record.disableStatus
        friend.showName = record.displayName; friend.roleId = record.roleID
        friend.onlineStatus = record.isOnline; friend.userType = record.userType
        let success = existing == nil ? sdk.toolAddMyFriend(with: friend) : sdk.toolUpdateMyFriend(with: friend)
        if !success { throw ContactBusinessError.invalidInput("好友资料缓存保存失败，请重新读取") }
    }

    /// 分组默认组包含未指定分组的普通好友，组内按在线/离线/注销排列。
    private func loadGroups() throws -> [FriendBusinessGroup] {
        let friends = sdk.toolGetMyFriendList() ?? []
        let cachedGroups: [LingIMFriendGroupModel]? = sdk.toolGetMyFriendGroupList()
        guard let cachedGroups else { throw ContactBusinessError.invalidInput("好友分组缓存读取失败，请刷新重试") }
        return cachedGroups.filter { $0.delFlag == 0 }.map { group in
            let members = friends.filter { $0.userType == 0 && ($0.ugUuid == group.ugUuid || (group.ugType == -1 && ($0.ugUuid ?? "").isEmpty)) }.map {
                ContactRecord(id: $0.friendUserUID ?? "", account: $0.userName ?? "", nickname: $0.nickname ?? "", remarks: $0.remarks ?? "", description: $0.descRemark ?? "", avatar: $0.avatar ?? "", isOnline: $0.onlineStatus, disableStatus: $0.disableStatus, userType: $0.userType, roleID: $0.roleId)
            }
            let sorted = ContactSorter.sorted(members).sorted { left, right in
                let l = left.isDeleted ? 2 : (left.isOnline ? 0 : 1), r = right.isDeleted ? 2 : (right.isOnline ? 0 : 1)
                return l != r ? l < r : left.sortName < right.sortName
            }
            return FriendBusinessGroup(id: group.ugUuid ?? "", name: group.ugName ?? "", order: group.ugOrder, isDefault: group.ugType == -1, members: sorted)
        }
    }

    /// 仅解析业务好友/群码；PC登录、文本与导航码均不进入本模块。
    private func decodeQR(_ data: Any) throws -> BusinessQRTarget {
        guard let result = data as? [String: Any], let resultPayload = Mapper<ContactBusinessPayload>().map(JSON: result), [1, 2].contains(resultPayload.integer("code")), let raw = result["data"] as? String,
              let json = raw.data(using: .utf8), let fields = try JSONSerialization.jsonObject(with: json) as? [String: Any] else { throw ContactBusinessError.malformedResponse }
        if resultPayload.integer("code") == 1, let user = fields["userInfo"] as? [String: Any], let mapped = Mapper<ContactBusinessPayload>().map(JSON: user), !mapped.text("uid").isEmpty { return .user(id: mapped.text("uid")) }
        if resultPayload.integer("code") == 2, let group = fields["groupInfo"] as? [String: Any], let mapped = Mapper<ContactBusinessPayload>().map(JSON: group), mapped.integer("groupStatus", default: -1) == 1, !mapped.text("gid").isEmpty {
            let inviter = Mapper<ContactBusinessPayload>().map(JSON: fields)?.text("shareUserUid") ?? ""
            return .group(id: mapped.text("gid"), name: mapped.text("gName"), avatar: mapped.text("avatar"), inviter: inviter, isMember: Mapper<ContactBusinessPayload>().map(JSON: fields)?.flag("isOnGroup") == true, needsApproval: mapped.flag("isNeedVerify"))
        }
        throw ContactBusinessError.invalidInput("此二维码不是有效的好友或群业务二维码")
    }
}

extension ContactsBusinessStore {
    /// 全局唯一业务状态与角色权限所有者由登录生命周期统一准备和释放。
    static let shared = ContactsBusinessStore(client: SDKContactsBusinessClient(), permission: { UserRoleAuthorityStore.shared.current?.allows($0) == true }, ownAccount: { UserSessionStore.shared.currentUser?.userName })
}
