import Foundation

@main
struct NetworkRecoveryChecks {
    @MainActor
    static func main() async throws {
        await reconnectChecks()
        print("Network reconnect checks passed")
    }
    @MainActor
    static func reconnectChecks() async {
        let session = IMReconnectSession(userUID: "fixture-user", lastLiceseId: "fixture-license")
        let cached = OSSLegacyEndpoint(host: "cached.example.com", port: 9000)
        let fresh = OSSLegacyEndpoint(host: "fresh.example.com", port: 9001)
        var refreshes = 0
        var now: TimeInterval = 100
        var valid = true
        let engine = IMLoggedInReconnectEngine(session: session, clock: { now },
            isCurrentSession: { $0 == session && valid }, cachedNodes: { [cached] },
            refreshNodes: { refreshes += 1; return IMReconnectNodes(nodes: [fresh]) }, probe: { $0 == fresh })
        let winner = await result(engine)
        precondition(winner.0 == fresh && refreshes == 1)
        let cooled = await result(engine)
        precondition(cooled.0 == nil && cooled.1 == "navigation_refresh_cooldown" && refreshes == 1)
        now += 61
        _ = await result(engine)
        precondition(refreshes == 2)

        let direct = IMLoggedInReconnectEngine(session: session, isCurrentSession: { _ in true },
            cachedNodes: { [cached, cached] }, refreshNodes: { preconditionFailure("Cached winner refreshed") },
            probe: { _ in true })
        let directResult = await result(direct)
        precondition(directResult.0 == cached)

        // DNS1 刷新返回的首项已经完成 ECDH；缓存仍须探测，刷新首胜直接交 SDK 正式连接。
        var nativeProbes = 0
        let native = IMLoggedInReconnectEngine(session: session,
            isCurrentSession: { _ in true }, cachedNodes: { [cached] }, refreshNodes: { IMReconnectNodes(nodes: [fresh, cached], probedNode: fresh) },
            probe: { _ in nativeProbes += 1; return false })
        let nativeResult = await result(native)
        precondition(nativeResult.0 == fresh && nativeProbes == 1)

        // DNS1开启时仍可能返回旧五路：第一项不可达，必须探测后选第二项。
        var fallbackProbes: [OSSLegacyEndpoint] = []
        let fallback = IMLoggedInReconnectEngine(session: session,
            isCurrentSession: { _ in true }, cachedNodes: { [] },
            refreshNodes: { IMReconnectNodes(nodes: [cached, fresh]) },
            probe: { node in fallbackProbes.append(node); return node == fresh })
        let fallbackResult = await result(fallback)
        precondition(fallbackResult.0 == fresh && fallbackProbes.contains(cached) && fallbackProbes.contains(fresh))
        let unreachable = IMLoggedInReconnectEngine(session: session,
            isCurrentSession: { _ in true }, cachedNodes: { [] },
            refreshNodes: { IMReconnectNodes(nodes: [cached], probedNode: fresh) }, probe: { _ in false })
        let unreachableResult = await result(unreachable)
        precondition(unreachableResult.0 == nil && unreachableResult.1 == "tcp_nodes_unreachable")

        enum ProbeFailure: Error { case rejected }
        var throwRefreshes = 0
        let partialFailure = IMLoggedInReconnectEngine(session: session,
            isCurrentSession: { _ in true }, cachedNodes: { [cached, fresh] },
            refreshNodes: { throwRefreshes += 1; return IMReconnectNodes(nodes: []) },
            probe: { node in
                if node == cached { throw ProbeFailure.rejected }
                try await Task<Never, Never>.sleep(nanoseconds: 5_000_000)
                return true
            })
        let survivingResult = await result(partialFailure)
        precondition(survivingResult.0 == fresh && throwRefreshes == 0)
        let allThrow = IMLoggedInReconnectEngine(session: session,
            isCurrentSession: { _ in true }, cachedNodes: { [cached] },
            refreshNodes: { throwRefreshes += 1; return IMReconnectNodes(nodes: [fresh]) },
            probe: { node in if node == cached { throw ProbeFailure.rejected }; return true })
        let afterThrow = await result(allThrow)
        precondition(afterThrow.0 == fresh && throwRefreshes == 1)

        var timeoutCallbacks = 0
        let deadline = IMLoggedInReconnectEngine(session: session, timeout: 0.01,
            isCurrentSession: { _ in true }, cachedNodes: { [] },
            refreshNodes: { try await Task<Never, Never>.sleep(nanoseconds: 80_000_000); return IMReconnectNodes(nodes: [fresh]) },
            probe: { _ in true })
        let timeoutResult: (OSSLegacyEndpoint?, String?) = await withCheckedContinuation { continuation in
            deadline.begin { node, reason in timeoutCallbacks += 1; continuation.resume(returning: (node, reason)) }
        }
        precondition(timeoutResult.0 == nil && timeoutResult.1 == "tcp_probe_timeout")
        try? await Task<Never, Never>.sleep(nanoseconds: 100_000_000)
        precondition(timeoutCallbacks == 1)

        var staleCallbacks = 0
        let stale = IMLoggedInReconnectEngine(session: session, timeout: 0.04,
            isCurrentSession: { _ in valid }, cachedNodes: { [cached] }, refreshNodes: { IMReconnectNodes(nodes: [fresh]) },
            probe: { _ in try? await Task<Never, Never>.sleep(nanoseconds: 30_000_000); return true })
        stale.begin { _, _ in staleCallbacks += 1 }
        try? await Task<Never, Never>.sleep(nanoseconds: 2_000_000)
        valid = false
        stale.cancel()
        try? await Task<Never, Never>.sleep(nanoseconds: 60_000_000)
        precondition(staleCallbacks == 0)

        valid = true
        var secondCallbacks = 0
        stale.begin { _, _ in staleCallbacks += 1 }
        stale.begin { _, _ in secondCallbacks += 1 }
        try? await Task<Never, Never>.sleep(nanoseconds: 60_000_000)
        precondition(staleCallbacks == 0 && secondCallbacks == 1)
    }

    @MainActor
    static func result(_ engine: IMLoggedInReconnectEngine) async -> (OSSLegacyEndpoint?, String?) {
        await withCheckedContinuation { continuation in
            engine.begin { continuation.resume(returning: ($0, $1)) }
        }
    }
}
