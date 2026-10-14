import Foundation


@MainActor final class BusinessMock: ContactBusinessClient {
    var calls: [ContactBusinessOperation] = []
    var suspended: CheckedContinuation<ContactBusinessResponse, Error>?
    var delay = false
    var response = ContactBusinessResponse(success: true)
    var error: Error?
    var staleProfile: ContactRecord?
    /// 测试客户端隔离真实SDK，允许手动恢复迟到回执。
    func request(_ operation: ContactBusinessOperation, identity: ContactsIdentity) async throws -> ContactBusinessResponse {
        calls.append(operation)
        if let error { throw error }
        if case .profile = operation, let staleProfile { return ContactBusinessResponse(profile: staleProfile, isFriend: true) }
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
        // 离开添加好友页清空搜索，迟到回执不能重新填回历史用户。
        let searchMock = BusinessMock()
        let searchStore = ContactsBusinessStore(client: searchMock)
        searchStore.prepare(userUID: "A", license: "club")
        searchMock.response.contacts = [ContactRecord(id: "old", nickname: "历史用户")]
        await searchStore.search("oldAccount")
        assert(searchStore.searchResults.map(\.id) == ["old"])
        searchStore.clearSearch()
        assert(searchStore.searchResults.isEmpty && !searchStore.isSearching)
        assert(searchStore.profiles["old"] != nil)
        searchMock.delay = true
        let pendingSearch = Task { await searchStore.search("lateAccount") }
        while searchMock.suspended == nil { await Task.yield() }
        assert(searchStore.isSearching)
        searchStore.clearSearch()
        searchMock.suspended?.resume(returning: searchMock.response)
        await pendingSearch.value
        assert(searchStore.searchResults.isEmpty && !searchStore.isSearching)
        searchMock.delay = false
        searchMock.response.contacts = [ContactRecord(id: "new", nickname: "当前用户")]
        await searchStore.search("newAccount")
        assert(searchStore.searchResults.map(\.id) == ["new"])
        searchMock.error = ContactBusinessError.server(code: -1, message: "用户不存在！")
        await searchStore.search("missingAccount")
        assert(searchStore.searchResults.isEmpty && searchStore.errorMessage == nil)
        searchMock.error = URLError(.notConnectedToInternet)
        await searchStore.search("unreachableAccount")
        assert(searchStore.searchResults.isEmpty && searchStore.errorMessage != nil)
        print("用户不存在转空态、网络失败保留错误回归通过")
        print("搜索退出清空、迟到回执隔离与再次搜索回归通过")
        let remarkMock = BusinessMock()
        let oldRemark = ContactRecord(id: "B", nickname: "好友", remarks: "旧备注", description: "旧描述")
        let savedRemark = ContactRecord(id: "B", nickname: "好友", remarks: "新备注", description: "新描述")
        remarkMock.response.profile = savedRemark
        remarkMock.response.isFriend = true
        remarkMock.staleProfile = oldRemark
        let remarkStore = ContactsBusinessStore(client: remarkMock)
        remarkStore.prepare(userUID: "A", license: "club")
        remarkStore.reconcileContacts([oldRemark])
        let remarkSaved = await remarkStore.perform(.setRemark(friendID: "B", remark: "新备注", description: "新描述"))
        assert(remarkSaved && remarkStore.profiles["B"] == savedRemark)
        assert(!remarkMock.calls.contains(.profile("B")), "保存确认后的新资料不能被紧接着的旧回读覆盖")
        remarkMock.response.success = false
        let remarkFailed = await remarkStore.perform(.setRemark(friendID: "B", remark: "失败备注", description: ""))
        assert(!remarkFailed && remarkStore.profiles["B"] == savedRemark)
        print("备注确认写入不被旧回读覆盖、失败不修改资料回归通过")
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
        // SDK默认组允许返回空名称，各界面必须仍能显示并区分分组。
        mock.response.groups = [
            FriendBusinessGroup(id: "default", name: "", order: 0, isDefault: true, members: []),
            FriendBusinessGroup(id: "blank", name: " \n\t", order: 1, isDefault: true, members: []),
            FriendBusinessGroup(id: "renamed", name: "我的好友", order: 2, isDefault: true, members: []),
            FriendBusinessGroup(id: "custom", name: "工作", order: 3, isDefault: false, members: [])
        ]
        await store.reload()
        guard store.groups.map(\.displayName) == ["默认分组", "默认分组", "我的好友", "工作"] else {
            throw ContactBusinessError.invalidInput("默认分组名称兜底失败")
        }
        assert(store.groups[0].name.isEmpty && store.groups[0].id == "default")
        let beforeDelete = mock.calls.count
        let deletedDefault = await store.perform(.deleteGroup(id: "default"))
        assert(!deletedDefault)
        assert(mock.calls.count == beforeDelete)
        print("默认分组空名、空白名、重命名与不可删除回归通过")
        let reorderMock = BusinessMock()
        reorderMock.response.groups = [
            FriendBusinessGroup(id: "first", name: "默认分组", order: 10, isDefault: true, members: []),
            FriendBusinessGroup(id: "middle", name: "工作", order: 30, isDefault: false, members: []),
            FriendBusinessGroup(id: "last", name: "家人", order: 70, isDefault: false, members: [])
        ]
        let reorderStore = ContactsBusinessStore(client: reorderMock)
        reorderStore.prepare(userUID: "A", license: "club")
        await reorderStore.reload()
        _ = await reorderStore.moveGroup(id: "middle", toIndex: 0)
        assert(reorderMock.calls.contains(.reorderGroup(id: "middle", order: 10)))
        _ = await reorderStore.moveGroup(id: "middle", toIndex: 2)
        assert(reorderMock.calls.contains(.reorderGroup(id: "middle", order: 70)))
        _ = await reorderStore.moveGroup(id: "last", toIndex: 1)
        assert(reorderMock.calls.contains(.reorderGroup(id: "last", order: 30)))
        let beforeNoOp = reorderMock.calls.count
        _ = await reorderStore.moveGroup(id: "first", toIndex: 0)
        _ = await reorderStore.moveGroup(id: "last", toIndex: 2)
        _ = await reorderStore.moveGroup(id: "missing", toIndex: 0)
        _ = await reorderStore.moveGroup(id: "middle", toIndex: -1)
        assert(reorderMock.calls.count == beforeNoOp)
        print("分组前后及拖动复用真实目标排序值、边界不提交回归通过")
        print("通讯录业务规则离线检查通过")
    }
}
