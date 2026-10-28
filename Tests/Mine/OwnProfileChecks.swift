import Foundation

@MainActor final class FakeProfileClient: OwnProfileClient {
    var changes: [OwnProfileChange] = []
    var applied: [OwnProfileChange] = []
    var uploadCount = 0
    var fail = false
    var suspended = false
    var pending: CheckedContinuation<Void, Error>?
    func upload(_ file: URL, context: ChatContext) async throws -> String {
        uploadCount += 1
        if fail { throw OwnProfileError.invalid("上传失败") }
        return "https://example.invalid/avatar/test.jpg"
    }
    func save(_ change: OwnProfileChange, context: ChatContext) async throws {
        changes.append(change)
        if suspended { try await withCheckedThrowingContinuation { pending = $0 } }
        if fail { throw OwnProfileError.invalid("保存失败") }
    }
    func apply(_ change: OwnProfileChange, context: ChatContext) throws { applied.append(change) }
    // 故意保留回执，让测试验证生产Store自身的迟到保护。
    func cancel() {}
}

@main struct OwnProfileChecks {
    @MainActor static func main() async throws {
        var count = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message); count += 1
        }
        let context = ChatContext(userUID: "a", tenantID: "t", sessionID: UUID(), route: ChatRoute(id: "a", kind: .single, title: "", avatarURL: ""))
        var valid = true
        let client = FakeProfileClient()
        let store = OwnProfileStore(context: context, nickname: "原昵称", client: client, isCurrent: { _ in valid })
        check(!store.canSaveNickname, "原昵称不可重复保存")
        store.nickname = " \n "
        check(!store.canSaveNickname, "空白不可提交")
        store.nickname = String(repeating: "中", count: 30)
        check(store.canSaveNickname, "30个中文可保存")
        store.nickname += "a"
        check(!store.canSaveNickname, "31个UTF16不可提交")
        store.nickname = String(repeating: "🙂", count: 15)
        check(store.canSaveNickname, "15个双UTF16 emoji可保存")
        store.nickname += "🙂"
        check(!store.canSaveNickname, "emoji不按Swift字符数误放行")
        store.nickname = "O'Neil’"
        check(store.normalizedNickname == "ONeil", "旧端引号规则")
        check(await store.saveNickname(), "昵称保存成功")
        check(client.applied == [.nickname("ONeil")], "受理后采用提交快照")
        check(!store.canSaveNickname, "成功后不能重复提交")
        store.nickname = "失败草稿"; client.fail = true
        check(!(await store.saveNickname()), "失败不能成功关闭")
        check(store.nickname == "失败草稿" && client.applied.count == 1, "失败保稿及旧资料")
        client.fail = false; client.suspended = true
        let request = Task { await store.saveNickname() }
        while client.pending == nil { await Task.yield() }
        check(store.busy, "在途显示忙碌")
        check(!(await store.saveNickname()), "阻止重复提交")
        store.close(); client.pending?.resume(); client.pending = nil
        check(!(await request.value) && client.applied.count == 1, "关闭后的迟到成功不落地")
        let next = OwnProfileStore(context: context, nickname: "旧", client: client, isCurrent: { _ in valid })
        next.nickname = "新"
        let switched = Task { await next.saveNickname() }
        while client.pending == nil { await Task.yield() }
        valid = false; client.pending?.resume(); client.pending = nil
        check(!(await switched.value) && client.applied.count == 1, "同UID新认证轮次也拒绝旧回执")
        valid = true; client.suspended = false
        let avatarStore = OwnProfileStore(context: context, nickname: "旧", client: client, isCurrent: { _ in valid })
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([1,2,3]).write(to: file)
        check(await avatarStore.saveAvatar(file), "头像先上传再更新资料")
        check(client.uploadCount == 1 && client.applied.last == .avatar("https://example.invalid/avatar/test.jpg"), "提交真实上传资源")
        check(!FileManager.default.fileExists(atPath: file.path), "完成清临时文件")
        client.fail = true; try Data([1,2,3]).write(to: file)
        let previous = client.changes.count
        check(!(await avatarStore.saveAvatar(file)), "上传失败")
        check(client.changes.count == previous && !FileManager.default.fileExists(atPath: file.path), "上传失败不改资料且清理文件")
        print("个人资料生产Store检查 \(count)/\(count) 通过")
    }
}
