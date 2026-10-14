import Foundation

@MainActor final class GroupsMock: GroupsClient {
    var pending: CheckedContinuation<GroupRecord, Error>?
    var delay = false
    var cachePending = false
    var loadedGroups: [GroupRecord]?
    var group = GroupRecord(id: "realGroup", name: "服务器群", avatar: "", role: 2, memberCount: 3)
    /// 注入群事件不访问真实账号。
    func observe(_ onChange: @escaping @MainActor () -> Void) {}
    /// Store隔离测试保留悬挂回执用于模拟SDK迟到结果。
    func reset() {}
    /// 群列表仅返回测试快照。
    func loadGroups(for userUID: String) async throws -> [GroupRecord] { loadedGroups ?? [group] }
    /// 模拟真实已建群但缓存失败及创建回执迟到。
    func createGroup(userUID: String, nickname: String, members: [ContactRecord]) async throws -> GroupRecord {
        if delay { return try await withCheckedThrowingContinuation { pending = $0 } }
        if cachePending { throw GroupCreationError.cachePending(group) }
        return group
    }
}

@main struct GroupsChecks {
    /// 离线验证选人规则，禁止系统账号、注销、预置重复及数量越界。
    @MainActor static func main() async throws {
        let ordinary = ContactRecord(id: "friend", nickname: "普通")
        let another = ContactRecord(id: "second")
        let system = ContactRecord(id: "100002", userType: 1)
        let deleted = ContactRecord(id: "deleted", disableStatus: 4)
        let selection = GroupMemberSelection(contacts: [ordinary, another, system, deleted, ordinary], preselectedIDs: ["friend"], excludedIDs: [])
        assert(selection.available.count == 2)
        assert(selection.selectedIDs == ["friend"])
        assert(!selection.canSubmit(minimum: 2, maximum: 200))
        var updated = selection
        updated.toggle("second", maximum: 200)
        assert(updated.canSubmit(minimum: 2, maximum: 200))
        updated.toggle("friend", maximum: 200)
        assert(updated.selectedIDs.contains("friend"))
        assert(GroupRole(rawValue: 0) == .member && GroupRole(rawValue: 2) == .owner)
        let client = GroupsMock(), store = GroupsStore(client: GroupsMock())
        store.prepare(userUID: "self", license: "club")
        let tooFew = await store.create(members: [ordinary], nickname: "本人")
        assert(tooFew == nil)
        let isolated = GroupsStore(client: client)
        isolated.prepare(userUID: "self", license: "club")
        client.cachePending = true
        let acknowledged = await isolated.create(members: [ordinary, another], nickname: "本人")
        assert(acknowledged?.id == "realGroup" && isolated.errorMessage?.contains("已创建") == true)
        client.cachePending = false; client.delay = true
        let task = Task { await isolated.create(members: [ordinary, another], nickname: "本人") }
        while client.pending == nil { await Task.yield() }
        isolated.prepare(userUID: "self", license: "another")
        client.pending?.resume(returning: client.group)
        let stale = await task.value
        assert(stale == nil && isolated.groups.isEmpty)
        // 建群回执已有真实人数，紧接着的缓存可能仍是人数为0的部分记录。
        client.delay = false
        isolated.prepare(userUID: "self", license: "club")
        client.loadedGroups = [GroupRecord(id: client.group.id, name: client.group.name, avatar: "", role: 2, memberCount: 0)]
        let created = await isolated.create(members: [ordinary, another], nickname: "本人")
        guard created?.memberCount == 3, isolated.groups.first?.memberCount == 3 else {
            throw NSError(domain: "GroupsChecks", code: 2, userInfo: [NSLocalizedDescriptionKey: "建群成功后列表人数显示0，创建回执为3"])
        }
        await isolated.reload()
        assert(isolated.groups.first?.memberCount == 3)
        client.loadedGroups = [GroupRecord(id: client.group.id, name: client.group.name, avatar: "", role: 2, memberCount: 2)]
        await isolated.reload()
        assert(isolated.groups.first?.memberCount == 2, "真实非零人数减少仍需更新")
        client.loadedGroups = []
        await isolated.reload()
        assert(isolated.groups.isEmpty, "退出群仍从列表移除")
        // 打开群聊刷新资料会改变SDK数据库行顺序，返回后列表不能随之跳动。
        let first = GroupRecord(id: "A", name: "群A", avatar: "", role: 0, memberCount: 3)
        let second = GroupRecord(id: "B", name: "群B", avatar: "", role: 0, memberCount: 4)
        let third = GroupRecord(id: "C", name: "群C", avatar: "", role: 0, memberCount: 5)
        client.loadedGroups = [first, second, third]
        await isolated.reload()
        let refreshedFirst = GroupRecord(id: "A", name: "新的群名", avatar: "new.png", role: 1, memberCount: 6)
        client.loadedGroups = [second, third, refreshedFirst]
        await isolated.reload()
        guard isolated.groups.map(\.id) == ["A", "B", "C"], isolated.groups.first == refreshedFirst else {
            throw NSError(domain: "GroupsChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: "返回群列表后已点击群移动到底部"])
        }
        let joined = GroupRecord(id: "D", name: "新加入的群", avatar: "", role: 0, memberCount: 2)
        client.loadedGroups = [third, refreshedFirst, joined, joined]
        await isolated.reload()
        assert(isolated.groups.map(\.id) == ["A", "C", "D"])
        isolated.prepare(userUID: "different", license: "club")
        client.loadedGroups = [joined, third, first]
        await isolated.reload()
        assert(isolated.groups.map(\.id) == ["D", "C", "A"])
        print("群列表返回稳定顺序、更新资料、增删与切账号重置回归通过")
        print("群选人/真实回执/缓存待同步/跨租户隔离检查通过")
    }
}
