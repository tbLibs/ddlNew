import Foundation

/// 只巡检已认证的前台会话；外部状态变化先取消，所有 await 后再核对本轮所有权。
@MainActor
final class IMNetworkQualityEngine {
    private let eligible: @MainActor () -> Bool
    private let nodes: @MainActor () -> [OSSLegacyEndpoint]
    private let current: @MainActor () -> OSSLegacyEndpoint?
    private let refresh: @MainActor () async throws -> [OSSLegacyEndpoint]
    private let probe: @MainActor (OSSLegacyEndpoint) async throws -> Double?
    private let switchNode: @MainActor (OSSLegacyEndpoint) async -> Bool
    private let clock: @MainActor () -> TimeInterval
    private let interval: TimeInterval
    private var policy: IMNetworkQualityPolicy
    private var generation = UUID()
    private var monitor: Task<Void, Never>?
    private(set) var isProbing = false

    init(interval: TimeInterval = 30, cooldown: TimeInterval = 60,
         clock: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         eligible: @escaping @MainActor () -> Bool,
         nodes: @escaping @MainActor () -> [OSSLegacyEndpoint],
         current: @escaping @MainActor () -> OSSLegacyEndpoint?,
         refresh: @escaping @MainActor () async throws -> [OSSLegacyEndpoint],
         probe: @escaping @MainActor (OSSLegacyEndpoint) async throws -> Double?,
         switchNode: @escaping @MainActor (OSSLegacyEndpoint) async -> Bool) {
        self.interval = interval; self.clock = clock; self.eligible = eligible
        self.nodes = nodes; self.current = current; self.refresh = refresh
        self.probe = probe; self.switchNode = switchNode
        policy = IMNetworkQualityPolicy(cooldown: cooldown)
    }

    func start() {
        guard monitor == nil else { return }
        let runID = generation
        monitor = Task { [weak self] in
            do { try await Task<Never, Never>.sleep(nanoseconds: 1_000_000_000) } catch { return }
            while !Task.isCancelled {
                guard let self, self.generation == runID else { return }
                await self.runOnce()
                do { try await Task<Never, Never>.sleep(nanoseconds: UInt64(self.interval * 1_000_000_000)) }
                catch { return }
            }
        }
    }

    /// SDK 断线竞速、后台、退出和换邀请码都会使迟到结果失效。
    func cancel() {
        generation = UUID()
        monitor?.cancel(); monitor = nil
        isProbing = false
    }

    func runOnce() async {
        guard eligible(), !isProbing else { return }
        isProbing = true
        let runID = generation
        defer { if generation == runID { isProbing = false } }
        do {
            var samples = try await measure(nodes(), runID: runID)
            try check(runID)
            policy.record(samples)
            if policy.shouldRefresh(samples, current: current(), now: clock()) {
                policy.didAttemptRefresh(now: clock())
                do {
                    let refreshed = try await refresh()
                    try check(runID)
                    // 新导航已关闭检测时，不能继续探测或使用旧轮结果切节点。
                    samples = try await measure(refreshed, runID: runID)
                    try check(runID)
                    // 刷新后的样本只用于选节点，不重复累计本轮连续异常。
                } catch is CancellationError { throw CancellationError() }
                catch { try check(runID) }
            }
            try check(runID)
            guard let candidate = policy.candidate(samples, current: current(), now: clock()) else { return }
            policy.didAttemptSwitch(now: clock())
            _ = await switchNode(candidate)
        } catch { /* 探测和导航失败保留当前连接，下一轮在冷却结束后再评估。 */ }
    }

    private func measure(_ candidates: [OSSLegacyEndpoint], runID: UUID) async throws -> [IMNetworkQualitySample] {
        try check(runID)
        var unique: [OSSLegacyEndpoint] = []
        // 当前连接必须参与同轮比较；导航刷新后旧节点可能不再出现在候选列表。
        if let connected = current() { unique.append(connected) }
        for node in candidates where !unique.contains(node) {
            if unique.count == 16 { break }
            unique.append(node)
        }
        return try await withThrowingTaskGroup(of: IMNetworkQualitySample.self) { group in
            for node in unique {
                group.addTask { [self] in
                    var latency: Double?
                    for attempt in 0..<3 {
                        try await check(runID)
                        do { latency = try await probe(node) }
                        catch is CancellationError { throw CancellationError() }
                        catch { latency = nil }
                        try await check(runID)
                        if let value = latency, value.isFinite, value > 0 { break }
                        latency = nil
                        if attempt < 2 { try await Task<Never, Never>.sleep(nanoseconds: 100_000_000) }
                    }
                    return IMNetworkQualitySample(node: node, latencyMilliseconds: latency)
                }
            }
            defer { group.cancelAll() }
            var result: [IMNetworkQualitySample] = []
            for try await sample in group { result.append(sample) }
            return result
        }
    }

    private func check(_ runID: UUID) throws {
        try Task<Never, Never>.checkCancellation()
        guard generation == runID, eligible() else { throw CancellationError() }
    }
}
