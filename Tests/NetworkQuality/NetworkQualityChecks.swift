import Foundation

@main
struct NetworkQualityChecks {
    static let current = OSSLegacyEndpoint(host: "current.example.com", port: 9000)
    static let fast = OSSLegacyEndpoint(host: "fast.example.com", port: 9001)
    static let fresh = OSSLegacyEndpoint(host: "fresh.example.com", port: 9002)

    @MainActor
    static func main() async {
        policyChecks()
        await engineChecks()
        await staleCallbackChecks()
        print("Network quality checks passed: thresholds, RTT preference, cooldown, retry, navigation recovery, session and lifecycle cancellation")
    }

    static func samples(_ baseline: Double?, _ alternate: Double?) -> [IMNetworkQualitySample] {
        [IMNetworkQualitySample(node: current, latencyMilliseconds: baseline),
         IMNetworkQualitySample(node: fast, latencyMilliseconds: alternate)]
    }

    static func policyChecks() {
        var policy = IMNetworkQualityPolicy()
        let healthy = samples(300, 100)
        policy.record(healthy)
        precondition(policy.candidate(healthy, current: current, now: 100) == fast)
        policy.didAttemptSwitch(now: 100)
        precondition(policy.candidate(healthy, current: current, now: 159) == nil)
        precondition(policy.candidate(healthy, current: current, now: 160) == fast)
        precondition(policy.candidate(samples(200, 150), current: current, now: 160) == nil)
        precondition(policy.candidate(samples(100, 100), current: current, now: 160) == nil)
        precondition(policy.candidate(samples(100, nil), current: current, now: 160) == nil)
        precondition(policy.candidate(samples(100, .nan), current: current, now: 160) == nil)
        precondition(policy.candidate(healthy, current: nil, now: 160) == nil)

        var degraded = IMNetworkQualityPolicy()
        for _ in 0..<4 { degraded.record(samples(650, 600)) }
        precondition(degraded.candidate(samples(650, 600), current: current, now: 100) == nil)
        degraded.record(samples(650, 600))
        precondition(degraded.candidate(samples(650, 600), current: current, now: 100) == fast)
        degraded.record(samples(600, 550))
        precondition(degraded.candidate(samples(600, 550), current: current, now: 100) == nil)

        var failed = IMNetworkQualityPolicy()
        for _ in 0..<2 { failed.record(samples(nil, 100)) }
        precondition(failed.candidate(samples(nil, 100), current: current, now: 100) == nil)
        failed.record(samples(nil, 100))
        precondition(failed.candidate(samples(nil, 100), current: current, now: 100) == fast)
        precondition(failed.shouldRefresh(samples(nil, 100), current: current, now: 100))
        failed.didAttemptRefresh(now: 100)
        precondition(!failed.shouldRefresh(samples(nil, nil), current: current, now: 159))
        precondition(failed.shouldRefresh(samples(nil, nil), current: current, now: 160))
        failed.record(samples(100, 100))
        precondition(!failed.shouldRefresh(samples(100, 100), current: current, now: 160))
    }

    @MainActor
    static func engineChecks() async {
        var enabled = false
        var probes = 0
        var switches: [OSSLegacyEndpoint] = []
        var now: TimeInterval = 100
        let engine = IMNetworkQualityEngine(clock: { now }, eligible: { enabled },
            nodes: { [current, fast, fast] }, current: { current },
            refresh: { preconditionFailure("Healthy probes cannot refresh navigation") },
            probe: { node in probes += 1; return node == current ? 300 : 100 },
            switchNode: { switches.append($0); return true })
        // 导航禁用、未 AUTH、后台、退出和竞速占用都通过同一入口阻止实际探测。
        await engine.runOnce()
        precondition(probes == 0 && switches.isEmpty)
        enabled = true
        await engine.runOnce()
        precondition(probes == 2 && switches == [fast])
        await engine.runOnce()
        precondition(switches.count == 1)
        now += 60
        await engine.runOnce()
        precondition(switches.count == 2)
        enabled = false
        await engine.runOnce()
        precondition(probes == 6)

        var refreshes = 0
        var attempts: [String: Int] = [:]
        var refreshed = false
        var recoverySwitches: [OSSLegacyEndpoint] = []
        var recoveryNow: TimeInterval = 100
        let recovery = IMNetworkQualityEngine(clock: { recoveryNow }, eligible: { true },
            nodes: { refreshed ? [fresh] : [current, fast] }, current: { current },
            refresh: { refreshes += 1; refreshed = true; return [fresh] },
            probe: { node in
                attempts[node.host, default: 0] += 1
                return node == fresh ? 50 : nil
            }, switchNode: { recoverySwitches.append($0); return true })
        await recovery.runOnce()
        precondition(refreshes == 1 && recoverySwitches.isEmpty)
        precondition(attempts[fast.host] == 3 && attempts[fresh.host] == 1)
        recoveryNow += 30
        await recovery.runOnce()
        recoveryNow += 30
        await recovery.runOnce()
        precondition(recoverySwitches == [fresh])
        precondition(refreshes == 2)
    }

    @MainActor
    static func staleCallbackChecks() async {
        var valid = true
        var pending: [CheckedContinuation<Double?, Error>] = []
        var switches = 0
        var refreshes = 0
        let engine = IMNetworkQualityEngine(eligible: { valid }, nodes: { [current, fast] }, current: { current },
            refresh: { refreshes += 1; return [fast] },
            probe: { _ in try await withCheckedThrowingContinuation { pending.append($0) } },
            switchNode: { _ in switches += 1; return true })
        let run = Task { await engine.runOnce() }
        while pending.count < 2 { await Task.yield() }
        // 模拟后台、邀请码或用户变化、SDK 断线竞速抢占：即使恢复可用旧轮也不能切换。
        valid = false
        engine.cancel()
        valid = true
        pending.forEach { $0.resume(returning: 300) }
        pending.removeAll()
        await run.value
        precondition(switches == 0 && refreshes == 0 && !engine.isProbing)

        var waiting: CheckedContinuation<[OSSLegacyEndpoint], Error>?
        let navigation = IMNetworkQualityEngine(eligible: { valid }, nodes: { [current] }, current: { current },
            refresh: { try await withCheckedThrowingContinuation { waiting = $0 } },
            probe: { _ in nil }, switchNode: { _ in switches += 1; return true })
        let navigationRun = Task { await navigation.runOnce() }
        while waiting == nil { await Task.yield() }
        valid = false
        navigation.cancel()
        waiting?.resume(returning: [fresh])
        await navigationRun.value
        precondition(switches == 0 && !navigation.isProbing)
    }
}
