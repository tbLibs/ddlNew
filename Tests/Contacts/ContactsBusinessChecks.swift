import Foundation


@MainActor final class BusinessMock: ContactBusinessClient {
    var calls: [ContactBusinessOperation] = []
    var suspended: CheckedContinuation<ContactBusinessResponse, Error>?
    var delay = false
    var response = ContactBusinessResponse(success: true)
    /// 测试客户端隔离真实SDK，允许手动恢复迟到回执。
    func request(_ operation: ContactBusinessOperation, identity: ContactsIdentity) async throws -> ContactBusinessResponse {
        calls.append(operation)
        if delay { return try await withCheckedThrowingContinuation { suspended = $0 } }
        return response
    }
    /// 离线观察不连接网络。
    func observe(_ onChange: @escaping @MainActor () -> Void) {}
    /// 测试中由Store自身轮次隔离回执。
    func reset() {}
}

@main struct ContactsBusinessChecks {
    /// 验证备注长度、审核受理语义、本机隐藏以及同UID重新登录隔离。
    @MainActor static func main() async throws {
        assert(ContactBusinessError.server(code: 44016, message: "").localizedDescription.contains("稍后"))
        assert(ContactBusinessError.server(code: 44017, message: "").localizedDescription.contains("已提交"))
        let mock = BusinessMock()
        let store = ContactsBusinessStore(client: mock, preferences: UserDefaults(suiteName: "ddlNew.contacts.test.\(UUID())")!)
        store.prepare(userUID: "A", license: "club")
        let own = ContactsBusinessStore(client: mock, ownAccount: { "myAccount" })
        own.prepare(userUID: "A", license: "club")
        await own.search(" myAccount ")
        assert(own.errorMessage?.contains("自己") == true && mock.calls.isEmpty)
        let result = await store.perform(.setRemark(friendID: "B", remark: String(repeating: "字", count: 51), description: ""))
        assert(!result && mock.calls.isEmpty)
        let emojiResult = await store.perform(.setRemark(friendID: "B", remark: String(repeating: "😀", count: 26), description: ""))
        assert(!emojiResult && mock.calls.isEmpty)
        let whitespaceResult = await store.perform(.setRemark(friendID: "B", remark: "   ", description: ""))
        assert(!whitespaceResult && mock.calls.isEmpty)
        let incoming = FriendApplicationRecord(id: "hash-10", hashKey: "hash", sendTime: "10", fromUID: "B", targetUID: "A", fromNickname: "B", targetNickname: "A", status: 0)
        assert(incoming.action(for: "A") == .accept)
        assert(incoming.action(for: "B") == .waiting)
        store.hide(incoming)
        assert(store.isHidden(incoming))
        store.prepare(userUID: "A", license: "another")
        assert(!store.isHidden(incoming))
        mock.delay = true
        let task = Task { await store.perform(.apply(friendID: "B")) }
        while mock.suspended == nil { await Task.yield() }
        store.prepare(userUID: "A", license: "club")
        mock.suspended?.resume(returning: ContactBusinessResponse(success: true))
        let accepted = await task.value
        assert(!accepted)
        assert(store.notice == nil)
        mock.delay = false
        mock.response.applications = [incoming]
        mock.response.unreadVersions = Dictionary(uniqueKeysWithValues: (0..<100).map { ("unseen\($0)", "10") })
        mock.response.unreadVersions["hash"] = "10"
        store.prepare(userUID: "A", license: "unreadClub")
        await store.reload()
        assert(store.unreadCount == 101)
        store.markVisible(incoming)
        assert(store.unreadCount == 100)
        await store.reload()
        assert(store.unreadCount == 100)
        mock.response.unreadVersions["hash"] = "11"
        await store.reload()
        assert(store.unreadCount == 101)
        store.hide(incoming)
        assert(store.unreadCount == 100)
        let resubmitted = FriendApplicationRecord(id: "hash-11", hashKey: "hash", sendTime: "11", fromUID: "B", targetUID: "A", fromNickname: "B", targetNickname: "A", status: 0)
        mock.response.applications = [resubmitted]
        mock.response.unreadVersions["hash"] = "12"
        await store.reload()
        assert(store.applications.count == 1 && store.unreadCount == 101)
        print("通讯录业务规则离线检查通过")
    }
}
