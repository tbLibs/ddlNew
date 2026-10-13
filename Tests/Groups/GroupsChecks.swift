import Foundation

@MainActor final class GroupsMock: GroupsClient {
    var pending: CheckedContinuation<GroupRecord, Error>?
    var delay = false
    var cachePending = false
    var group = GroupRecord(id: "realGroup", name: "服务器群", avatar: "", role: 2, memberCount: 3)
    /// 注入群事件不访问真实账号。
    func observe(_ onChange: @escaping @MainActor () -> Void) {}
    /// Store隔离测试保留悬挂回执用于模拟SDK迟到结果。
    func reset() {}
    /// 群列表仅返回测试快照。
    func loadGroups(for userUID: String) async throws -> [GroupRecord] { [group] }
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
        print("群选人/真实回执/缓存待同步/跨租户隔离检查通过")
    }
}
