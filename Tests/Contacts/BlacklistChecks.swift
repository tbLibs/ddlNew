//
//  BlacklistChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import Foundation

@MainActor private final class BlacklistClient: ContactBusinessClient {
    var response = ContactBusinessResponse()
    var error: Error?
    var calls: [ContactBusinessOperation] = []
    var delay = false
    var pending: CheckedContinuation<ContactBusinessResponse, Error>?
    /// 暂停回执验证写操作与换号隔离，不访问真实关系。
    func request(_ operation: ContactBusinessOperation, identity: ContactsIdentity) async throws -> ContactBusinessResponse {
        calls.append(operation)
        if let error { throw error }
        if delay { return try await withCheckedThrowingContinuation { pending = $0 } }
        return response
    }
    func observe(_ onChange: @escaping @MainActor () -> Void) {}
    func reset() {}
}

@main struct BlacklistChecks {
    /// 成功、拒绝、审核和迟到回执都必须保留真实黑名单语义。
    @MainActor static func main() async {
        let client = BlacklistClient(), store = ContactsBusinessStore(client: BlacklistClient())
        let subject = ContactsBusinessStore(client: client)
        subject.prepare(userUID: "A", license: "club")
        client.response.isBlack = false
        await subject.loadBlackState("B")
        precondition(subject.blackStates["B"] == false)
        client.response.success = false
        let refused = await subject.perform(.setBlack(friendID: "B", blocked: true))
        precondition(!refused && subject.blackStates["B"] == false)
        client.response.success = true
        client.error = ContactBusinessError.server(code: 44016, message: "")
        let reviewing = await subject.perform(.setBlack(friendID: "B", blocked: true))
        precondition(!reviewing && subject.blackStates["B"] == false)
        client.error = nil
        let blocked = await subject.perform(.setBlack(friendID: "B", blocked: true))
        precondition(blocked && subject.blackStates["B"] == true)
        client.response.contacts = [ContactRecord(id: "B", nickname: "乙", remarks: "备注乙")]
        await subject.loadBlacklist()
        precondition(subject.blacklist.map(\.id) == ["B"])
        let removed = await subject.perform(.setBlack(friendID: "B", blocked: false))
        precondition(removed && subject.blackStates["B"] == false && subject.blacklist.isEmpty)
        client.response.contacts = []
        let blockedAgain = await subject.perform(.setBlack(friendID: "B", blocked: true))
        precondition(blockedAgain && subject.blackStates["B"] == true)
        await subject.loadBlacklist()
        precondition(subject.blacklist.isEmpty && subject.blackStates["B"] == false, "权威空名单必须撤销旧拉黑状态，支持其他端解除后的刷新")
        let calls = client.calls.count
        let own = await subject.perform(.setBlack(friendID: "A", blocked: true))
        precondition(!own && client.calls.count == calls, "不能拉黑自己")
        client.delay = true
        let oldRead = Task { await subject.loadBlackState("B") }
        while client.pending == nil { await Task.yield() }
        let oldPending = client.pending
        client.delay = false
        let confirmed = await subject.perform(.setBlack(friendID: "B", blocked: true))
        precondition(confirmed)
        var stale = ContactBusinessResponse(); stale.isBlack = false
        oldPending?.resume(returning: stale); await oldRead.value
        precondition(subject.blackStates["B"] == true, "写操作确认后的旧查询不能覆盖拉黑状态")
        // 全量名单须使在途单人读取失效，即使读取已暂时清除了旧黑态键。
        client.pending = nil; client.delay = true
        let listPrecededRead = Task { await subject.loadBlackState("B") }
        while client.pending == nil { await Task.yield() }
        let listPrecededPending = client.pending
        client.delay = false; client.response.contacts = []
        await subject.loadBlacklist()
        stale.isBlack = true
        listPrecededPending?.resume(returning: stale); await listPrecededRead.value
        precondition(subject.blackStates["B"] == false && !subject.loadingBlackIDs.contains("B"), "权威空名单必须使在途旧黑态查询失效，不能再次禁止发消息")
        client.pending = nil
        client.delay = true
        let pending = Task { await subject.perform(.setBlack(friendID: "B", blocked: true)) }
        while client.pending == nil { await Task.yield() }
        subject.prepare(userUID: "A", license: "club")
        client.pending?.resume(returning: client.response)
        let late = await pending.value
        precondition(!late && subject.blackStates.isEmpty && subject.blacklist.isEmpty, "同UID重登不能消费旧拉黑回执")
        store.reset()
        print("Blacklist state checks passed")
    }
}
