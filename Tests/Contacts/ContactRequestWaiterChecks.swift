import Foundation

@main struct ContactRequestWaiterChecks {
    /// SDK重复回执只消费一次，取消可结束没有回调的Swift等待。
    @MainActor static func main() async throws {
        let once = ContactBusinessRequestWaiter<Int>()
        let result = try await once.run { once.finish(.success(1)); once.finish(.success(2)) }
        assert(result == 1)
        let pending = ContactBusinessRequestWaiter<Int>()
        var started = false
        let task = Task { try await pending.run { started = true } }
        while !started { await Task.yield() }
        task.cancel()
        do { _ = try await task.value; fatalError("取消等待不应成功") } catch is CancellationError {}
        pending.finish(.success(99))
        let reset = ContactBusinessRequestWaiter<Int>()
        let resetTask = Task { try await reset.run { reset.cancel() } }
        do { _ = try await resetTask.value; fatalError("会话撤销不应成功") } catch is CancellationError {}
        let gate = ContactProfileRequestGate()
        let old = gate.begin(userUID: "A", license: "club", friendUID: "B")
        let newest = gate.begin(userUID: "A", license: "club", friendUID: "B")
        assert(!gate.accepts(old, userUID: "A", license: "club", friendUID: "B"))
        gate.finish(old, userUID: "A", license: "club", friendUID: "B")
        assert(gate.accepts(newest, userUID: "A", license: "club", friendUID: "B"))
        assert(!gate.accepts(newest, userUID: "A", license: "another", friendUID: "B"))
        gate.reset()
        assert(!gate.accepts(newest, userUID: "A", license: "club", friendUID: "B"))
        print("资料写入共享版本4项通过")
        print("通讯录SDK等待重复回调/取消/撤销3项通过")
    }
}
