import Foundation
@main struct ProbeChecks {
    @MainActor static func main() async throws {
        let probe = MessageConnectivityProbe()
        var current = true
        var reconnects = 0
        await probe.run(isCurrent: { current }, probe: { true }, reconnect: { reconnects += 1 })
        precondition(reconnects == 0)
        await probe.run(isCurrent: { current }, probe: { false }, reconnect: { reconnects += 1 })
        precondition(reconnects == 1)
        await probe.run(isCurrent: { current }, probe: { current = false; return false }, reconnect: { reconnects += 1 })
        precondition(reconnects == 1)
        current = true
        await probe.run(isCurrent: { current }, probe: { probe.cancel(); return false }, reconnect: { reconnects += 1 })
        precondition(reconnects == 1)
        var entered = false
        var held: CheckedContinuation<Bool, Error>?
        let task = Task { await probe.run(isCurrent: { current }, probe: {
            entered = true
            return try await withCheckedThrowingContinuation { held = $0 }
        }, reconnect: { reconnects += 1 }) }
        while !entered { await Task.yield() }
        await probe.run(isCurrent: { current }, probe: { fatalError("duplicate probe") }, reconnect: {})
        task.cancel(); held?.resume(returning: false); await task.value
        precondition(reconnects == 1)
        print("Probe checks passed (success/failure/stale identity/cancel/single flight)")
    }
}
