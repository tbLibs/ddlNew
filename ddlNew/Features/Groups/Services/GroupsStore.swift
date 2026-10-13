//
//  GroupsStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import Combine

/// 群列表只读SDK库，建群成功后回读，退出立即清空。
@MainActor final class GroupsStore: ObservableObject {
    @Published private(set) var groups: [GroupRecord] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isCreating = false
    @Published private(set) var errorMessage: String?
    private let client: any GroupsClient
    private let permission: () -> Bool
    private var identity: ContactsIdentity?
    private var readRevision = UUID()
    private var isActivated = false

    /// 注入客户端与动态角色权限，禁止在测试里打开真实SDK数据库。
    init(client: any GroupsClient, permission: @escaping () -> Bool = { true }) { self.client = client; self.permission = permission }

    /// AUTH前订阅群同步，AUTH后根会话编排首次缓存读取。
    func prepare(userUID: String, license: String) {
        reset(); let identity = ContactsIdentity(userUID: userUID, license: license, generation: UUID())
        guard !userUID.isEmpty, !license.isEmpty else { return }
        self.identity = identity
        client.observe { [weak self] in
            guard let self, self.identity == identity, self.isActivated else { return }
            Task { await self.reload() }
        }
    }

    /// 同一会话读取群快照，迟到读取不得覆盖更新轮次。
    func reload() async {
        guard let identity else { return }
        isActivated = true
        let revision = UUID(); readRevision = revision; isLoading = true
        defer { if self.identity == identity, readRevision == revision { isLoading = false } }
        do {
            let groups = try await client.loadGroups(for: identity.userUID)
            guard self.identity == identity, readRevision == revision else { return }
            var seen = Set<String>()
            self.groups = groups.filter { !$0.id.isEmpty && seen.insert($0.id).inserted }
            errorMessage = nil
        } catch { if self.identity == identity, readRevision == revision { errorMessage = error.localizedDescription } }
    }

    /// 建群前再次验证好友数量及权限，服务端返回群ID后才开放聊天。
    func create(members: [ContactRecord], nickname: String) async -> GroupRecord? {
        guard let identity, !isCreating else { return nil }
        let selection = GroupMemberSelection(contacts: members, preselectedIDs: Set(members.map(\.id)), excludedIDs: [identity.userUID])
        guard permission(), selection.canSubmit(minimum: 2, maximum: 200), selection.selected.count == members.count else {
            errorMessage = "当前不能建群，请选择2至200位有效好友并确认权限"; return nil
        }
        isCreating = true; errorMessage = nil
        defer { if self.identity == identity { isCreating = false } }
        do {
            let group = try await client.createGroup(userUID: identity.userUID, nickname: nickname, members: selection.selected)
            guard self.identity == identity else { return nil }
            await reload()
            guard self.identity == identity else { return nil }
            return group
        } catch GroupCreationError.cachePending(let group) {
            guard self.identity == identity else { return nil }
            errorMessage = GroupCreationError.cachePending(group).localizedDescription
            return group
        } catch { if self.identity == identity { errorMessage = error.localizedDescription }; return nil }
    }

    /// 退出、换俱乐部或同UID重新登录均撤销创建与读取回执。
    func reset() { identity = nil; isActivated = false; readRevision = UUID(); client.reset(); groups = []; isLoading = false; isCreating = false; errorMessage = nil }
}
