//
//  ContactsBusinessStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import Combine

/// 编排好友关系操作，已有好友列表仍由ContactsStore拥有。
@MainActor final class ContactsBusinessStore: ObservableObject {
    @Published private(set) var applications: [FriendApplicationRecord] = []
    @Published private(set) var groups: [FriendBusinessGroup] = []
    @Published private(set) var searchResults: [ContactRecord] = []
    @Published private(set) var profiles: [String: ContactRecord] = [:]
    @Published private(set) var groupNicknames: [String: [String: String]] = [:]
    @Published private(set) var friendIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSearching = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var hasMoreApplications = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var notice: String?
    @Published private(set) var qrContent = ""
    @Published private(set) var qrExpiry = ""
    @Published private(set) var qrTarget: BusinessQRTarget?
    @Published private(set) var unreadCount = 0
    @Published private(set) var roleLabels: [Int: String] = [:]
    private(set) var identity: ContactsIdentity?
    private let client: any ContactBusinessClient
    private let preferences: UserDefaults
    private let permission: (String) -> Bool
    private let ownAccount: () -> String?
    private var page = 0
    private var isActivated = false
    private var pendingReload = false
    private var reloadTask: Task<Void, Never>?
    private var hidden: Set<String> = []
    private var unreadVersions: [String: String] = [:]
    private var hiddenUnreadHashes = Set<String>()
    private var hasUnreadSnapshot = false
    private var read: Set<String> = []
    private var firstVisibleVersions: [String: String] = [:]
    private var searchRevision = UUID()
    private var readRevision = UUID()
    private var operationRevision = UUID()
    private var profileRevisions: [String: UUID] = [:]
    private var accessRevisions: [String: UUID] = [:]
    private var nicknameRevisions: [String: [String: UUID]] = [:]
    private let persistenceKey = contactsApplicationStateKey

    /// 注入客户端、权限及本机偏好，测试不访问SDK或后端。
    init(client: any ContactBusinessClient, preferences: UserDefaults = .standard,
         permission: @escaping (String) -> Bool = { _ in true }, ownAccount: @escaping () -> String? = { nil }) {
        self.client = client; self.preferences = preferences; self.permission = permission; self.ownAccount = ownAccount
    }

    /// AUTH前设置会话归属并订阅申请变化，业务请求留在AUTH后。
    func prepare(userUID: String, license: String) {
        reset()
        guard !userUID.isEmpty, !license.isEmpty else { return }
        let identity = ContactsIdentity(userUID: userUID, license: license, generation: UUID())
        self.identity = identity
        let saved = preferences.dictionary(forKey: persistenceKey)?[identity.persistenceKey] as? [String: Any] ?? [:]
        hidden = Set(saved["hidden"] as? [String] ?? []); read = Set(saved["read"] as? [String] ?? [])
        firstVisibleVersions = saved["visibleVersions"] as? [String: String] ?? [:]
        client.observe { [weak self] in
            guard let self, self.identity == identity, self.isActivated else { return }
            Task { await self.reload() }
        }
    }

    /// 合并加载期间的SDK变化，当前读取完成后补读一次，不丢同步事件。
    func reload() async {
        guard let identity else { return }
        if isLoading {
            pendingReload = true
            if let reloadTask { await reloadTask.value }
            return
        }
        isActivated = true; isLoading = true
        let revision = UUID(); readRevision = revision
        let task = Task { [weak self] in
            guard let self else { return }
            repeat {
                self.pendingReload = false
                await self.reloadSnapshot(identity: identity, revision: revision)
                guard self.identity == identity, self.readRevision == revision, !Task.isCancelled else { return }
            } while self.pendingReload
            self.isLoading = false; self.reloadTask = nil
        }
        reloadTask = task
        await task.value
    }

    /// 每次读取保留旧快照直到成功，并在每个等待后核对会话归属。
    private func reloadSnapshot(identity: ContactsIdentity, revision: UUID) async {
        do {
            let result = try await client.request(.applications(page: 1), identity: identity)
            guard self.identity == identity, readRevision == revision else { return }
            applications = uniqueApplications(result.applications).filter { !hidden.contains($0.id) }
            hiddenUnreadHashes = Set(result.applications.filter { hidden.contains($0.id) }.map(\.hashKey))
            page = 1; hasMoreApplications = result.hasMore
            updateUnread()
            if let unreadResult = try? await client.request(.unreadApplications, identity: identity) {
                guard self.identity == identity, readRevision == revision else { return }
                unreadVersions = unreadResult.unreadVersions; hasUnreadSnapshot = true; associateFirstVisibleVersions(); updateUnread()
            }
            let groupResult = try await client.request(.groups, identity: identity)
            guard self.identity == identity, readRevision == revision else { return }
            groups = groupResult.groups.sorted { $0.order < $1.order }
            if let roles = try? await client.request(.roleLabels, identity: identity) {
                guard self.identity == identity, readRevision == revision else { return }
                roleLabels = roles.roleLabels
            }
            errorMessage = nil
        } catch {
            guard self.identity == identity, readRevision == revision else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// 分页只在成功后推进页码，以hashKey和sendTime去重。
    func loadMoreApplications() async {
        guard let identity, hasMoreApplications, !isLoading else { return }
        isLoading = true
        let revision = UUID(); readRevision = revision
        do {
            let result = try await client.request(.applications(page: page + 1), identity: identity)
            guard self.identity == identity, readRevision == revision else { return }
            applications = uniqueApplications(applications + result.applications).filter { !hidden.contains($0.id) }
            page += 1; hasMoreApplications = result.hasMore; updateUnread()
        } catch { if self.identity == identity, readRevision == revision { errorMessage = error.localizedDescription } }
        guard self.identity == identity, readRevision == revision else { return }
        isLoading = false
        if pendingReload { pendingReload = false; await reload() }
    }

    /// 搜索只在提交时请求精确账号，清空查询使迟到结果失效。
    func search(_ query: String) async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let revision = UUID(); searchRevision = revision
        searchResults = []; errorMessage = nil; isSearching = false
        guard let identity, !query.isEmpty else { return }
        if query == ownAccount()?.trimmingCharacters(in: .whitespacesAndNewlines) { errorMessage = "这是你自己的账号"; return }
        isSearching = true
        defer { if self.identity == identity, searchRevision == revision { isSearching = false } }
        do {
            let result = try await client.request(.search(query), identity: identity)
            guard self.identity == identity, searchRevision == revision else { return }
            searchResults = result.contacts.filter { $0.id != identity.userUID }
            for contact in result.contacts { profiles[contact.id] = contact }
            errorMessage = nil
        } catch { if self.identity == identity, searchRevision == revision { errorMessage = error.localizedDescription } }
    }

    /// 群来源访问须读实时群详情；缺失角色、离群或禁私聊均关闭访问。
    func checkGroupAccess(_ groupID: String?) async -> Bool {
        guard let groupID else { return true }
        guard let identity else { return false }
        let revision = UUID(); accessRevisions[groupID] = revision
        do {
            let result = try await client.request(.groupAccess(groupID), identity: identity)
            guard self.identity == identity, accessRevisions[groupID] == revision else { return false }
            if !result.canAccessProfile { errorMessage = "当前群不允许查看成员资料或发起私聊" }
            return result.canAccessProfile
        } catch { if self.identity == identity { errorMessage = error.localizedDescription }; return false }
    }

    /// 好友缓存实时变化时优先更新资料，删除立即撤销好友操作资格。
    func reconcileContacts(_ contacts: [ContactRecord]) {
        let validIDs = Set(contacts.map(\.id))
        friendIDs = validIDs
        for contact in contacts where profiles[contact.id] != nil { profiles[contact.id] = contact }
    }

    /// 打开资料时重新确认当前关系并读取完整资料。
    @discardableResult func loadProfile(_ contactID: String, sourceGroupID: String? = nil, allowCreatingFriend: Bool = false) async -> Bool {
        guard let identity else { return false }
        let revision = UUID(); profileRevisions[contactID] = revision
        guard await checkGroupAccess(sourceGroupID), self.identity == identity, profileRevisions[contactID] == revision else { return false }
        do {
            let result = try await client.request(allowCreatingFriend ? .profileAfterAcceptance(contactID) : .profile(contactID), identity: identity)
            guard self.identity == identity, profileRevisions[contactID] == revision else { return false }
            guard let profile = result.profile else { throw ContactBusinessError.malformedResponse }
            profiles[contactID] = profile
            if result.isFriend { friendIDs.insert(contactID) } else { friendIDs.remove(contactID) }
            if let sourceGroupID { await loadGroupNickname(groupID: sourceGroupID, contactID: contactID) }
            guard self.identity == identity, profileRevisions[contactID] == revision else { return false }
            return true
        } catch {
            if self.identity == identity, profileRevisions[contactID] == revision { errorMessage = error.localizedDescription }
            return false
        }
    }

    /// 群昵称只按群与目标用户读取，不改写全局好友昵称。
    func groupNickname(in groupID: String, for contactID: String) -> String? { groupNicknames[groupID]?[contactID] }

    /// 同群同用户昵称的旧回执失效；别的群可以独立保留自己的名称。
    private func loadGroupNickname(groupID: String, contactID: String) async {
        guard let identity else { return }
        let revision = UUID(); nicknameRevisions[groupID, default: [:]][contactID] = revision
        do {
            let response = try await client.request(.groupNickname(groupID: groupID, userUID: contactID), identity: identity)
            guard self.identity == identity, nicknameRevisions[groupID]?[contactID] == revision else { return }
            guard let nickname = response.groupNickname else { throw ContactBusinessError.malformedResponse }
            groupNicknames[groupID, default: [:]][contactID] = nickname
        } catch {
            if self.identity == identity, nicknameRevisions[groupID]?[contactID] == revision { errorMessage = error.localizedDescription }
        }
    }

    /// 提交前校验输入与权限，服务器回执后重读真实关系而非伪造成功。
    @discardableResult func perform(_ operation: ContactBusinessOperation, sourceGroupID: String? = nil) async -> Bool {
        guard let identity, !isSubmitting else { return false }
        do { try validate(operation) } catch { errorMessage = error.localizedDescription; return false }
        isSubmitting = true; errorMessage = nil; notice = nil
        let revision = UUID(); operationRevision = revision
        defer { if self.identity == identity, operationRevision == revision { isSubmitting = false } }
        do {
            guard await checkGroupAccess(sourceGroupID), self.identity == identity, operationRevision == revision else { return false }
            let response = try await client.request(operation, identity: identity)
            guard self.identity == identity, operationRevision == revision else { return false }
            guard response.success else { throw ContactBusinessError.invalidInput("服务器未完成此操作，请刷新状态后重试") }
            qrContent = response.qrCode; qrExpiry = response.expiry; qrTarget = response.qrTarget
            switch operation {
            case .apply: notice = "好友申请已发送，等待对方验证"
            case .accept(let friendID), .setRemark(let friendID, _, _), .moveFriend(let friendID, _):
                let accepting: Bool
                if case .accept = operation { accepting = true } else { accepting = false }
                let refreshed = await loadProfile(friendID, sourceGroupID: sourceGroupID, allowCreatingFriend: accepting)
                await reload()
                guard self.identity == identity, operationRevision == revision else { return false }
                notice = refreshed ? "操作完成" : "操作已提交，资料待同步，请刷新确认"
            case .deleteFriend(let id):
                profiles.removeValue(forKey: id); friendIDs.remove(id); await reload()
                guard self.identity == identity, operationRevision == revision else { return false }
                notice = "好友及本机聊天记录已删除"
            case .createGroup, .renameGroup, .reorderGroup, .deleteGroup:
                await reload()
                guard self.identity == identity, operationRevision == revision else { return false }
                notice = "分组已更新"
            case .joinGroup: notice = "入群请求已提交，请刷新群列表确认结果"
            default: break
            }
            return true
        } catch {
            guard self.identity == identity, operationRevision == revision else { return false }
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// 在提交时再次核对权限与当前好友，避免页面打开后权限变化绕过。
    private func validate(_ operation: ContactBusinessOperation) throws {
        switch operation {
        case .apply(let id), .accept(let id):
            guard permission("allowAddFriend"), id != identity?.userUID else { throw ContactBusinessError.invalidInput("当前账号不能添加该用户") }
        case .setRemark(_, let remark, let description):
            guard remark.utf16.count <= 50, description.utf16.count <= 200 else { throw ContactBusinessError.invalidInput("备注最多50字，描述最多200字") }
            guard remark.isEmpty || !remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ContactBusinessError.invalidInput("备注不能只包含空格") }
            if case .setRemark(let id, _, _) = operation, !friendIDs.contains(id) { throw ContactBusinessError.invalidInput("好友关系已变化，请刷新资料") }
        case .deleteFriend(let id), .moveFriend(let id, _):
            guard friendIDs.contains(id) else { throw ContactBusinessError.invalidInput("好友关系已变化，请刷新资料") }
        case .createGroup(let name), .renameGroup(_, let name):
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ContactBusinessError.invalidInput("请输入分组名称") }
        case .deleteGroup(let id):
            guard groups.contains(where: { $0.id == id && !$0.isDefault }) else { throw ContactBusinessError.invalidInput("默认分组不可删除") }
        default: break
        }
    }

    /// 本机隐藏不提交拒绝请求，下一次sendTime不同的申请仍会出现。
    func hide(_ application: FriendApplicationRecord) {
        hidden.insert(application.id); hiddenUnreadHashes.insert(application.hashKey)
        if let version = unreadVersions[application.hashKey] { read.insert(syncReadKey(application.hashKey, version: version)) }
        applications.removeAll { $0.id == application.id }; saveState(); updateUnread()
    }

    /// 仅标记实际出现的申请，按UID和俱乐部隔离已读偏好。
    func markVisible(_ application: FriendApplicationRecord) {
        var changed = read.insert(application.id).inserted
        if let version = unreadVersions[application.hashKey] {
            if firstVisibleVersions[application.id] == nil { firstVisibleVersions[application.id] = version; changed = true }
            changed = read.insert(syncReadKey(application.hashKey, version: version)).inserted || changed
        }
        if changed { saveState(); updateUnread() }
    }

    /// 首次拿到版本时关联此前已经可见的申请，后续版本变化不自动标已读。
    private func associateFirstVisibleVersions() {
        var changed = false
        for application in applications where read.contains(application.id) && firstVisibleVersions[application.id] == nil {
            guard let version = unreadVersions[application.hashKey] else { continue }
            firstVisibleVersions[application.id] = version
            read.insert(syncReadKey(application.hashKey, version: version)); changed = true
        }
        if changed { saveState() }
    }

    /// 名称仅取服务端真实角色配置，注销或关闭展示权限时隐藏。
    func roleName(roleID: Int, isDeleted: Bool) -> String? { guard !isDeleted, permission("showRoleName") else { return nil }; return roleLabels[roleID] }

    /// 查询持久化隐藏状态供页面和离线检查使用。
    func isHidden(_ application: FriendApplicationRecord) -> Bool { hidden.contains(application.id) }

    /// 同一页与跨页采用真实申请身份去重。
    private func uniqueApplications(_ records: [FriendApplicationRecord]) -> [FriendApplicationRecord] {
        var seen = Set<String>(); return records.filter { !$0.id.isEmpty && seen.insert($0.id).inserted }
    }

    /// 本机新朋友角标只统计来自对方且尚未实际显示的申请。
    private func updateUnread() {
        if hasUnreadSnapshot { unreadCount = unreadVersions.filter { !hiddenUnreadHashes.contains($0.key) && !read.contains(syncReadKey($0.key, version: $0.value)) }.count }
        else { unreadCount = applications.filter { $0.fromUID != identity?.userUID && !read.contains($0.id) }.count }
        if let identity { client.updateUnreadCount(unreadCount, identity: identity) }
    }

    /// 服务端更新版本与申请身份分开保存，新申请或状态更新仍可成为新未读。
    private func syncReadKey(_ hash: String, version: String) -> String { "sync|\(hash.utf8.count):\(hash)|\(version)" }

    /// 属性列表保存少量申请身份，不保存用户资料或凭据。
    private func saveState() {
        guard let identity else { return }
        var all = preferences.dictionary(forKey: persistenceKey) ?? [:]
        all[identity.persistenceKey] = ["hidden": Array(hidden), "read": Array(read), "visibleVersions": firstVisibleVersions]
        preferences.set(all, forKey: persistenceKey)
    }

    /// 退出或同UID重新AUTH时使请求与SDK观察同时失效。
    func reset() {
        identity = nil; reloadTask?.cancel(); reloadTask = nil; pendingReload = false; client.reset(); readRevision = UUID(); searchRevision = UUID(); operationRevision = UUID(); profileRevisions = [:]; accessRevisions = [:]; nicknameRevisions = [:]
        applications = []; groups = []; searchResults = []; roleLabels = [:]; profiles = [:]; groupNicknames = [:]; friendIDs = []
        hidden = []; read = []; firstVisibleVersions = [:]; unreadVersions = [:]; hiddenUnreadHashes = []; hasUnreadSnapshot = false; page = 0; isActivated = false; unreadCount = 0; hasMoreApplications = false
        isLoading = false; isSearching = false; isSubmitting = false; errorMessage = nil; notice = nil; qrContent = ""; qrExpiry = ""; qrTarget = nil
    }
}
