//
//  ContactsAdversarialChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

@MainActor final class AcceptanceContactsClient: ContactBusinessClient {
    var calls: [ContactBusinessOperation] = []
    var suspendProfiles = false
    var suspendRemarks = false
    var emptyRemarkConfirmation = false
    var waiting: [CheckedContinuation<ContactBusinessResponse, Error>] = []
    var profileFailure = false
    var emptyProfile = false
    var searchWaits: [CheckedContinuation<ContactBusinessResponse, Error>] = []
    var suspendSearch = false
    /// 支持错序资料与提交后换号，回执由测试逐次注入。
    func request(_ operation: ContactBusinessOperation, identity: ContactsIdentity) async throws -> ContactBusinessResponse {
        calls.append(operation)
        if case .search = operation, suspendSearch { return try await withCheckedThrowingContinuation { searchWaits.append($0) } }
        if case .setRemark(let id, let remark, let description) = operation {
            if suspendRemarks { return try await withCheckedThrowingContinuation { waiting.append($0) } }
            if emptyRemarkConfirmation { return ContactBusinessResponse() }
            return ContactBusinessResponse(profile: ContactRecord(id: id, nickname: "验收好友", remarks: remark, description: description), isFriend: true)
        }
        if case .profile = operation {
            if profileFailure { throw ContactBusinessError.malformedResponse }
            if emptyProfile { return ContactBusinessResponse() }
            if suspendProfiles { return try await withCheckedThrowingContinuation { waiting.append($0) } }
            return ContactBusinessResponse(profile: ContactRecord(id: "peer", nickname: "验收好友"), isFriend: true)
        }
        return ContactBusinessResponse()
    }
    /// 离线客户端不安装SDK观察，不触发外部业务请求。
    func observe(_ onChange: @escaping @MainActor () -> Void) {}
    /// 已提交回执保留以证明取消后迟到隔离。
    func reset() {}
}

@main struct ContactsAdversarialChecks {
    @MainActor static var failures = 0
    @MainActor static var checks = 0
    /// 独立运行原Store，记录输入守卫和资料回读真实行为。
    @MainActor static func main() async {
        let client = AcceptanceContactsClient()
        let defaults = UserDefaults(suiteName: "ddlNew.independent.contacts.acceptance")!
        defaults.removePersistentDomain(forName: "ddlNew.independent.contacts.acceptance")
        let store = ContactsBusinessStore(client: client, preferences: defaults)
        store.prepare(userUID: "me", license: "test-tenant")
        await store.loadProfile("peer")
        let count = client.calls.count
        let oversized = await store.perform(.setRemark(friendID: "peer", remark: String(repeating: "🙂", count: 26), description: ""))
        check(!oversized && client.calls.count == count, "C-017 UTF16备注52单位应在请求前拒绝")
        let blankCount = client.calls.count
        let blank = await store.perform(.setRemark(friendID: "peer", remark: "   ", description: ""))
        check(!blank && client.calls.count == blankCount, "C-017 全空格备注应拒绝")
        store.prepare(userUID: "me", license: "test-tenant")
        let staleCount = client.calls.count
        let stale = await store.perform(.setRemark(friendID: "stranger", remark: "备注", description: ""))
        check(!stale && client.calls.count == staleCount, "C-017 当前非好友不能用旧详情提交备注")
        client.suspendProfiles = true
        let first = Task { await store.loadProfile("peer") }
        guard await waitUntil({ client.waiting.count >= 1 }, "首次资料请求") else { exit(1) }
        let second = Task { await store.loadProfile("peer") }
        guard await waitUntil({ client.waiting.count >= 2 }, "第二次资料请求") else { exit(1) }
        client.waiting[1].resume(returning: ContactBusinessResponse(profile: ContactRecord(id: "peer", nickname: "最新资料"), isFriend: true))
        _ = await second.value
        client.waiting[0].resume(returning: ContactBusinessResponse(profile: ContactRecord(id: "peer", nickname: "旧资料"), isFriend: true))
        _ = await first.value
        check(store.profiles["peer"]?.nickname == "最新资料", "C-016 同UID资料错序旧结果失效")
        client.waiting.removeAll()
        client.suspendProfiles = false; client.suspendRemarks = true
        let accepted = Task { await store.perform(.setRemark(friendID: "peer", remark: "验收", description: "")) }
        guard await waitUntil({ !client.waiting.isEmpty }, "备注保存请求") else { exit(1) }
        store.prepare(userUID: "other", license: "other-tenant")
        client.waiting[0].resume(returning: ContactBusinessResponse(profile: ContactRecord(id: "peer", nickname: "旧用户资料"), isFriend: true))
        let acceptedResult = await accepted.value
        check(!acceptedResult && store.notice == nil && store.profiles.isEmpty, "C-G7 写操作回执期间换号不得向新用户发布成功")
        client.suspendRemarks = false; client.profileFailure = false
        store.prepare(userUID: "me", license: "test-tenant"); await store.loadProfile("peer")
        client.emptyRemarkConfirmation = true
        _ = await store.perform(.setRemark(friendID: "peer", remark: "验收", description: ""))
        check(store.notice != "操作完成" && store.errorMessage != nil, "C-017 缺少保存确认资料时不得伪报完成")
        client.emptyRemarkConfirmation = false
        let saved = await store.perform(.setRemark(friendID: "peer", remark: "已确认备注", description: "已确认描述"))
        check(saved && store.profiles["peer"]?.remarks == "已确认备注" && store.profiles["peer"]?.description == "已确认描述", "C-017 保存使用确认快照且不再回查旧资料")
        let incoming = FriendApplicationRecord(id: "hash-time", hashKey: "hash", sendTime: "time", fromUID: "peer", targetUID: "me", fromNickname: "对方", targetNickname: "我", status: 0)
        check(incoming.action(for: "me") == .accept && incoming.action(for: "peer") == .waiting, "C-010 好友申请方向")
        store.hide(incoming); check(store.isHidden(incoming), "C-012 本机隐藏保留正确身份")
        store.prepare(userUID: "me", license: "other-tenant"); check(!store.isHidden(incoming), "C-012 本机隐藏租户隔离")
        client.profileFailure = false; client.emptyProfile = true
        let missing = await store.loadProfile("peer")
        check(!missing && store.profiles["peer"] == nil && store.errorMessage != nil, "C-016 缺失资料不得伪造空好友")
        client.emptyProfile = false; await store.loadProfile("peer")
        store.reconcileContacts([])
        let deletedCalls = client.calls.count
        let deletedRemark = await store.perform(.setRemark(friendID: "peer", remark: "旧页备注", description: ""))
        check(!deletedRemark && client.calls.count == deletedCalls, "C-016 删除好友事件立即关闭旧资料写权限")
        store.reconcileContacts([ContactRecord(id: "peer", nickname: "同期新好友")])
        check(store.friendIDs.contains("peer") && store.profiles["peer"]?.nickname == "同期新好友", "C-016 新增好友事件更新旧陌生人资料关系")
        client.suspendSearch = true
        let olderSearch = Task { await store.search("first") }
        guard await waitUntil({ !client.searchWaits.isEmpty }, "首次搜索请求") else { exit(1) }
        check(store.isSearching, "C-013 等待查找显示加载状态")
        let newerSearch = Task { await store.search("second") }
        guard await waitUntil({ client.searchWaits.count >= 2 }, "第二次搜索请求") else { exit(1) }
        client.searchWaits[0].resume(returning: ContactBusinessResponse(contacts: [ContactRecord(id: "old")]))
        await olderSearch.value
        check(store.isSearching && store.searchResults.isEmpty, "C-013 旧搜索完成不能结束新搜索加载状态")
        client.searchWaits[1].resume(returning: ContactBusinessResponse(contacts: [ContactRecord(id: "new")]))
        await newerSearch.value
        check(!store.isSearching && store.searchResults.map(\.id) == ["new"], "C-013 最新搜索完成显示正确结果")
        let clearedSearch = Task { await store.search("clear") }
        guard await waitUntil({ client.searchWaits.count >= 3 }, "清空前搜索请求") else { exit(1) }
        await store.search(" \n ")
        client.searchWaits[2].resume(returning: ContactBusinessResponse(contacts: [ContactRecord(id: "late")]))
        await clearedSearch.value
        check(!store.isSearching && store.searchResults.isEmpty, "C-013 清空搜索立即结束加载并丢迟到结果")
        print("Independent Contacts Acceptance: \(checks - failures)/\(checks) passed; \(failures) failed")
        if failures > 0 { exit(1) }
    }
    /// 等待真实可观察状态有上限，协议变化应报告失败而非卡住整套验收。
    @MainActor static func waitUntil(_ condition: () -> Bool, _ label: String) async -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while !condition() {
            if ProcessInfo.processInfo.systemUptime >= deadline { check(false, "等待超时：" + label); return false }
            await Task.yield()
        }
        return true
    }

    /// 累计所有断言结果并以非零退出报告失败。
    @MainActor static func check(_ result: Bool, _ label: String) {
        checks += 1; if !result { failures += 1 }; print("\(result ? "PASS" : "FAIL") \(label)")
    }
}
