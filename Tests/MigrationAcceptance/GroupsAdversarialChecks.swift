// Created by taobo on 2026/10/13.
import Foundation

@MainActor final class AcceptanceGroupsClient: GroupsClient {
    var reads: [CheckedContinuation<[GroupRecord], Error>] = []
    var creation: CheckedContinuation<GroupRecord, Error>?
    var delayedReads = false
    var delayedCreation = false
    var creates = 0
    var cachePending = false
    var snapshot: [GroupRecord] = []
    /// 匿名测试事件不访问生产SDK。
    func observe(_ onChange: @escaping @MainActor () -> Void) {}
    /// 故意保留旧回执，验证Store本身能够隔离换号。
    func reset() {}
    /// 让两个群列表请求按反序完成。
    func loadGroups(for userUID: String) async throws -> [GroupRecord] {
        if delayedReads { return try await withCheckedThrowingContinuation { reads.append($0) } }
        return snapshot
    }
    /// 计数重复请求，并模拟已创建但缓存失败。
    func createGroup(userUID: String, nickname: String, members: [ContactRecord]) async throws -> GroupRecord {
        creates += 1
        if delayedCreation { return try await withCheckedThrowingContinuation { creation = $0 } }
        let group = GroupRecord(id: "qa-created", name: "匿名测试群", avatar: "", role: 2, memberCount: 3)
        if cachePending { throw GroupCreationError.cachePending(group) }
        return group
    }
}

@main struct GroupsAdversarialChecks {
    @MainActor static var count = 0
    /// 验证建群边界、动态权限、重复提交、乱序列表和跨租户迟到回执。
    @MainActor static func main() async {
        let client = AcceptanceGroupsClient()
        var allowed = true
        let store = GroupsStore(client: client, permission: { allowed })
        store.prepare(userUID: "qa-me", license: "qa-tenant")
        let friends = (0..<201).map { ContactRecord(id: "qa-\($0)") }
        let small = await store.create(members: [friends[0]], nickname: "匿名")
        check(small == nil && client.creates == 0, "C-029 少于2位不得发请求")
        let oversized = await store.create(members: friends, nickname: "匿名")
        check(oversized == nil && client.creates == 0, "C-029 超过200位不得发请求")
        let duplicate = await store.create(members: [friends[0], friends[0]], nickname: "匿名")
        check(duplicate == nil && client.creates == 0, "C-029 重复UID不能冒充2位好友")
        let selfMember = await store.create(members: [friends[0], ContactRecord(id: "qa-me")], nickname: "匿名")
        check(selfMember == nil && client.creates == 0, "C-029 本人不计入所选好友")
        allowed = false
        let forbidden = await store.create(members: Array(friends.prefix(2)), nickname: "匿名")
        check(forbidden == nil && client.creates == 0, "C-036 权限收回后提交拒绝")
        allowed = true; client.delayedCreation = true
        let first = Task { await store.create(members: Array(friends.prefix(200)), nickname: "匿名") }
        while client.creation == nil { await Task.yield() }
        let repeated = await store.create(members: Array(friends.prefix(2)), nickname: "匿名")
        check(repeated == nil && client.creates == 1 && store.isCreating, "C-029 正好200可提交且防重复请求")
        store.prepare(userUID: "qa-me", license: "qa-other-tenant")
        client.creation?.resume(returning: group("old"))
        let stale = await first.value
        check(stale == nil && store.groups.isEmpty && !store.isCreating, "C-G7 同UID换租户旧建群回执失效")
        client.delayedCreation = false; client.cachePending = true
        let acknowledged = await store.create(members: Array(friends.prefix(2)), nickname: "匿名")
        check(acknowledged?.id == "qa-created" && store.errorMessage?.contains("已创建") == true, "C-029 缓存失败仍保留已建群身份")
        client.delayedReads = true
        let oldRead = Task { await store.reload() }
        while client.reads.isEmpty { await Task.yield() }
        let newRead = Task { await store.reload() }
        while client.reads.count < 2 { await Task.yield() }
        client.reads[1].resume(returning: [group("new"), group("new"), group("")]); await newRead.value
        client.reads[0].resume(returning: [group("old")]); await oldRead.value
        check(store.groups.map(\.id) == ["new"] && !store.isLoading, "C-026 群列表乱序去重并排除空ID")
        let beforeExit = Task { await store.reload() }
        while client.reads.count < 3 { await Task.yield() }
        store.reset(); client.reads[2].resume(returning: [group("late")]); await beforeExit.value
        check(store.groups.isEmpty && store.errorMessage == nil && !store.isLoading, "C-G7 退出后迟到群列表不能回流")
        print("Independent groups acceptance: \(count)/\(count) passed")
    }
    /// 生产模型只使用匿名稳定群身份。
    static func group(_ id: String) -> GroupRecord { GroupRecord(id: id, name: "匿名群", avatar: "", role: 0, memberCount: 3) }
    /// 失败时退出并打印需求边界，不输出账号或网络信息。
    @MainActor static func check(_ condition: Bool, _ name: String) { guard condition else { print("FAIL \(name)"); exit(1) }; count += 1; print("PASS \(name)") }
}
