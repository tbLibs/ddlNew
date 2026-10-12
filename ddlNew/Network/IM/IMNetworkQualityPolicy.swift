import Foundation

nonisolated struct IMNetworkQualitySample: Sendable {
    let node: OSSLegacyEndpoint
    /// TCP 建连和 ECDH 完整握手的耗时；失败不能计成零延迟成功。
    let latencyMilliseconds: Double?
    var isAvailable: Bool {
        guard let latencyMilliseconds else { return false }
        return latencyMilliseconds.isFinite && latencyMilliseconds > 0
    }
}

/// 旧项目阈值：600ms、连续高延迟 5 轮、连续失败 3 轮。
nonisolated struct IMNetworkQualityPolicy {
    private(set) var failures: [String: Int] = [:]
    private(set) var highLatencies: [String: Int] = [:]
    private var lastSwitchAttempt: TimeInterval?
    private var lastRefreshAttempt: TimeInterval?
    let cooldown: TimeInterval

    init(cooldown: TimeInterval = 60) { self.cooldown = cooldown }

    mutating func record(_ samples: [IMNetworkQualitySample]) {
        let keys = Set(samples.map { key($0.node) })
        failures = failures.filter { keys.contains($0.key) }
        highLatencies = highLatencies.filter { keys.contains($0.key) }
        for sample in samples {
            let name = key(sample.node)
            failures[name] = sample.isAvailable ? 0 : (failures[name] ?? 0) + 1
            highLatencies[name] = sample.isAvailable && (sample.latencyMilliseconds ?? 0) > 600
                ? (highLatencies[name] ?? 0) + 1 : 0
        }
    }

    func shouldRefresh(_ samples: [IMNetworkQualitySample], current: OSSLegacyEndpoint?, now: TimeInterval) -> Bool {
        guard !samples.isEmpty, lastRefreshAttempt.map({ now - $0 >= cooldown }) ?? true else { return false }
        return !samples.contains(where: \.isAvailable)
            || current.map { (failures[key($0)] ?? 0) >= 3 } == true
    }

    mutating func didAttemptRefresh(now: TimeInterval) { lastRefreshAttempt = now }

    func candidate(_ samples: [IMNetworkQualitySample], current: OSSLegacyEndpoint?, now: TimeInterval) -> OSSLegacyEndpoint? {
        guard let current, lastSwitchAttempt.map({ now - $0 >= cooldown }) ?? true,
              let baseline = samples.first(where: { $0.node == current }),
              let best = samples.filter({ $0.isAvailable && $0.node != current })
                .min(by: { ($0.latencyMilliseconds ?? .infinity) < ($1.latencyMilliseconds ?? .infinity) }) else { return nil }
        // 当前节点连续异常时可切换；健康连接要求同时改善 100ms 和 20%，避免细微抖动来回切换。
        if !baseline.isAvailable {
            return (failures[key(current)] ?? 0) >= 3 ? best.node : nil
        }
        let latency = baseline.latencyMilliseconds ?? 0
        let bestLatency = best.latencyMilliseconds ?? 0
        let degraded = (highLatencies[key(current)] ?? 0) >= 5
        return bestLatency < latency && (degraded || (latency - bestLatency >= 100 && bestLatency <= latency * 0.8))
            ? best.node : nil
    }

    mutating func didAttemptSwitch(now: TimeInterval) { lastSwitchAttempt = now }
    private func key(_ node: OSSLegacyEndpoint) -> String { "\(node.host):\(node.port)" }
}
