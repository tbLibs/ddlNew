//
//  SDKGroupsClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore
import ObjectMapper
import ObjectiveC

/// 群客户端复用SDK群库与创建请求，绝不制造本地演示群。
@MainActor final class SDKGroupsClient: GroupsClient {
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }
    private var delegate: SDKGroupsDelegate?
    private var generation = UUID()
    private var createWaiter: ContactBusinessRequestWaiter<Data>?

    /// 群代理绑定客户端轮次，跨账号迟到事件丢弃。
    func observe(_ onChange: @escaping @MainActor () -> Void) {
        let revision = generation
        let delegate = SDKGroupsDelegate { [weak self] in
            Task { @MainActor [weak self] in guard let self, self.generation == revision else { return }; onChange() }
        }
        self.delegate = delegate; sdk.addGroupDelegate(delegate)
    }

    /// 释放代理同时使已提交创建回执失效。
    func reset() { generation = UUID(); createWaiter?.cancel(); createWaiter = nil; if let delegate { sdk.removeGroupDelegate(delegate) }; delegate = nil }

    /// 与SDK共享数据库锁，不能检查UID后读取其他用户群库。
    func loadGroups(for userUID: String) async throws -> [GroupRecord] {
        objc_sync_enter(sdk); defer { objc_sync_exit(sdk) }
        guard sdk.myUserID() == userUID, sdk.isUserDatabaseReady() else { throw ContactBusinessError.staleSession }
        let cachedGroups: [LingIMGroupModel]? = sdk.toolGetMyGroupList()
        guard let cachedGroups else { throw ContactBusinessError.invalidInput("群列表缓存读取失败，请刷新重试") }
        return cachedGroups.filter { $0.leaveGroupStatus == 0 && $0.groupStatus != 2 }.map { group in
            GroupRecord(id: group.groupId ?? "", name: group.groupName ?? "", avatar: group.groupAvatar ?? "", role: group.userGroupRole, memberCount: group.memberCount, isNeedVerify: group.isNeedVerify, isShowQRCode: group.isShowQrCode, isPrivateChat: group.isPrivateChat, isAllMuted: group.isGroupChat)
        }
    }

    /// 只提交仍在真实好友库且有效的2至200位成员，群主通过独立字段传递。
    func createGroup(userUID: String, nickname: String, members: [ContactRecord]) async throws -> GroupRecord {
        let revision = generation, license = OSSNavigationStore.shared.lastUsableLiceseId()
        guard sdk.myUserID() == userUID, sdk.isUserDatabaseReady(), UserRoleAuthorityStore.shared.current?.allows("createGroup") == true,
              (2...200).contains(members.count), Set(members.map(\.id)).count == members.count else { throw ContactBusinessError.invalidInput("当前无建群权限或人数不符合要求") }
        for member in members {
            guard member.id != userUID, let friend = sdk.toolCheckMyFriend(with: member.id), friend.userType == 0, friend.disableStatus != 4 else { throw ContactBusinessError.invalidInput("好友状态已变化，请重新选择") }
        }
        let params: NSMutableDictionary = ["userUid": userUID, "ownerUid": userUID, "ownerNickname": nickname,
                                           "groupMemberParams": members.map { ["userUid": $0.id, "nickName": $0.nickname] }]
        let waiter = ContactBusinessRequestWaiter<Data>(); createWaiter = waiter
        defer { if generation == revision { createWaiter = nil } }
        let bytes = try await waiter.run {
            sdk.createGroup(with: params, onSuccess: { data, _ in
                let bytes = try? JSONSerialization.data(withJSONObject: data ?? NSNull(), options: [.fragmentsAllowed])
                Task { @MainActor in
                    if let bytes { waiter.finish(.success(bytes)) }
                    else { waiter.finish(.failure(ContactBusinessError.malformedResponse)) }
                }
            }, onFailure: { code, message, _ in Task { @MainActor in waiter.finish(.failure(ContactBusinessError.server(code: code, message: message ?? ""))) } })
        }
        let data = try JSONSerialization.jsonObject(with: bytes, options: [.fragmentsAllowed])
        objc_sync_enter(sdk); defer { objc_sync_exit(sdk) }
        guard generation == revision, sdk.myUserID() == userUID, sdk.isUserDatabaseReady(), OSSNavigationStore.shared.lastUsableLiceseId() == license else { throw ContactBusinessError.staleSession }
        guard let fields = data as? [String: Any], let mapped = Mapper<ContactBusinessPayload>().map(JSON: fields), !mapped.text("groupId").isEmpty else { throw ContactBusinessError.malformedResponse }
        let group = LingIMGroupModel()
        group.groupId = mapped.text("groupId"); group.groupName = mapped.text("groupName"); group.groupAvatar = mapped.text("groupAvatar")
        group.memberCount = mapped.integer("memberCount"); group.userGroupRole = 2; group.groupStatus = mapped.integer("groupStatus", default: 1)
        group.isNeedVerify = mapped.flag("isNeedVerify"); group.isPrivateChat = mapped.flag("isPrivateChat"); group.isGroupChat = mapped.flag("isGroupChat")
        group.isShowQrCode = mapped.flag("isShowQrCode"); group.isMessageInform = 1; group.isActiveEnabled = 1
        let record = GroupRecord(id: group.groupId, name: group.groupName, avatar: group.groupAvatar, role: 2, memberCount: group.memberCount, isNeedVerify: group.isNeedVerify, isShowQRCode: group.isShowQrCode, isPrivateChat: group.isPrivateChat, isAllMuted: group.isGroupChat)
        guard sdk.toolInsertOrUpdateGroupModel(with: group) else { throw GroupCreationError.cachePending(record) }
        return record
    }
}

extension GroupsStore {
    /// 根会话统一拥有唯一群列表状态，权限在每次创建时动态查询。
    static let shared = GroupsStore(client: SDKGroupsClient(), permission: { UserRoleAuthorityStore.shared.current?.allows("createGroup") == true })
}
