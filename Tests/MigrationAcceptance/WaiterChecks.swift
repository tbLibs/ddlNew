//
//  WaiterChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

@main struct WaiterChecks {
    /// 验证真实等待器重复回调、取消后迟到与提前取消均单次结束。
    @MainActor static func main() async throws {
        let contact = ContactBusinessRequestWaiter<Int>()
        let first = try await contact.run { contact.finish(.success(7)); contact.finish(.success(9)); contact.cancel() }
        precondition(first == 7, "重复好友回调不得二次消费")
        let chat = SDKChatRequestWaiter<Int>()
        let second = try await chat.run { chat.finish(.success(11)); chat.finish(.success(12)); chat.cancel() }
        precondition(second == 11, "重复聊天回调不得二次消费")
        let cancelled = ContactBusinessRequestWaiter<Int>()
        cancelled.cancel()
        do { _ = try await cancelled.run { fatalError("提前取消后不得发请求") }; fatalError("提前取消应抛错") }
        catch is CancellationError {}
        let pending = SDKChatRequestWaiter<Int>()
        var started = false
        let task = Task { try await pending.run { started = true } }
        while !started { await Task.yield() }
        task.cancel()
        do { _ = try await task.value; fatalError("任务取消应抛错") }
        catch is CancellationError {}
        pending.finish(.success(100))
        print("Independent waiter acceptance: 4/4 passed")
    }
}
