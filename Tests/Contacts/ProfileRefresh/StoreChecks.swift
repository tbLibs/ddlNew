import Foundation

@main struct ProfileStoreChecks {
    @MainActor static func main() async {
        let client = MockContactsClient()
        let target = ContactsStore(client: client)
        let old = ContactRecord(id: "peer", nickname: "旧昵称", avatar: "old.png")
        let fresh = ContactRecord(id: "peer", nickname: "新昵称", avatar: "new.png")
        client.contacts = [old]; client.remoteContacts = [fresh]
        target.prepare(for: "user-a"); await target.reload()
        let start = Date(timeIntervalSince1970: 1000)
        await target.refreshVisibleProfile("peer", now: start)
        precondition(target.contacts == [fresh], "不进入详情也应请求并发布最新头像昵称")
        await target.refreshVisibleProfile("peer", now: start.addingTimeInterval(29))
        precondition(client.refreshCount == 1, "行重建和另一列表不能重复请求同一好友")
        await target.refreshVisibleProfile("peer", now: start.addingTimeInterval(30))
        precondition(client.refreshCount == 2)
        client.refreshFailure = NSError(domain: "offline", code: 1)
        await target.refreshVisibleProfile("peer", now: start.addingTimeInterval(60))
        precondition(target.contacts == [fresh] && target.errorMessage == nil, "失败保留展示且不弹出反复错误")
        await target.refreshVisibleProfile("peer", now: start.addingTimeInterval(61))
        precondition(client.refreshCount == 3, "失败同样退避")
        await target.refreshVisibleProfile("unknown", now: start)
        precondition(client.refreshCount == 3, "不会把陌生会话伪装为好友")
        client.refreshFailure = nil
        client.contacts = (1...5).map { ContactRecord(id: "peer-\($0)", nickname: "姓名\($0)") }
        await target.reload(); client.suspendRefreshes = true
        let tasks = (1...4).map { id in Task { await target.refreshVisibleProfile("peer-\(id)", now: start) } }
        while client.profileWaiters.count < 4 { await Task.yield() }
        await target.refreshVisibleProfile("peer-5", now: start)
        precondition(client.refreshCount == 7, "最多同时请求四个好友")
        let duplicate = Task { await target.refreshVisibleProfile("peer-1", now: start) }
        for _ in 0..<20 { await Task.yield() }
        precondition(client.refreshCount == 7, "同一好友共享正在进行的请求")
        target.reset()
        client.activeUserUID = "user-b"; client.contacts = [ContactRecord(id: "other")]
        target.prepare(for: "user-b"); await target.reload()
        let waiters = client.profileWaiters; client.profileWaiters = [:]
        for waiter in waiters.values { waiter.resume() }
        for task in tasks { await task.value }; await duplicate.value
        precondition(target.contacts.map(\.id) == ["other"], "旧账号响应不能覆盖新账号")
        client.suspendRefreshes = false
        client.contacts = [ContactRecord(id: "system", userType: 1), ContactRecord(id: "deleted", disableStatus: 4)]
        await target.reload()
        await target.refreshVisibleProfile("system", now: start)
        await target.refreshVisibleProfile("deleted", now: start)
        precondition(client.refreshCount == 7)
        var versions = ContactRequestVersions()
        let explicit = versions.begin(for: "peer")
        precondition(versions.beginIfIdle(for: "peer") == nil, "静默刷新不抢占详情／保存")
        versions.finish(explicit, for: "peer")
        let silent = versions.beginIfIdle(for: "peer")!
        _ = versions.begin(for: "peer")
        precondition(!versions.accepts(silent, for: "peer"), "显式操作使静默旧响应失效")
        target.reset()
        print("可见好友刷新、限流、失败退避及会话隔离检查通过")
    }
}
