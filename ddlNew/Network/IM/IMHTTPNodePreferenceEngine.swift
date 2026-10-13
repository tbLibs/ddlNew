//
//  IMHTTPNodePreferenceEngine.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// HTTP 择优缓存仅属于一次账号、邀请码和导航版本，不与 TCP 握手质量混用。
nonisolated struct IMHTTPNodePreferenceContext: Equatable, Sendable {
    let userUID: String
    let lastLiceseId: String
    let navigationGeneration: String
    let enabled: Bool
    let interval: TimeInterval
    let nodes: [URL]

    var pollingInterval: TimeInterval { interval > 0 && interval.isFinite ? interval : 300 }
}

nonisolated struct IMHTTPNodePreferenceSample: Equatable, Sendable {
    let node: URL
    var successCount = 0
    var totalMilliseconds: Double = 0
    var lastSucceeded = false
    var averageMilliseconds: Double { successCount > 0 ? totalMilliseconds / Double(successCount) : .infinity }
}

/// 只在旧连接真正从后台返回时检查一次，重复生命周期通知不会重发 PING。
nonisolated struct IMForegroundSessionGate {
    private var pending: Bool
    init(isInBackground: Bool) { pending = isInBackground }
    mutating func enteredBackground() { pending = true }
    mutating func takeForegroundCheck() -> Bool {
        guard pending else { return false }
        pending = false
        return true
    }
}

@MainActor
final class IMHTTPNodePreferenceEngine {
    private let context: @MainActor () -> IMHTTPNodePreferenceContext?
    private let current: @MainActor () -> URL?
    private let hostRevision: @MainActor () -> UInt64
    private let probe: @MainActor (URL) async throws -> Double?
    private let select: @MainActor (URL, IMHTTPNodePreferenceContext) -> Bool
    private let clock: @MainActor () -> TimeInterval
    private let cooldown: TimeInterval
    private var generation = UUID()
    private var monitor: Task<Void, Never>?
    private var cacheContext: IMHTTPNodePreferenceContext?
    private var lastSwitch: TimeInterval?
    private(set) var rankedSamples: [IMHTTPNodePreferenceSample] = []
    private(set) var isProbing = false

    init(cooldown: TimeInterval = 60,
         clock: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         context: @escaping @MainActor () -> IMHTTPNodePreferenceContext?,
         current: @escaping @MainActor () -> URL?,
         hostRevision: @escaping @MainActor () -> UInt64 = { 0 },
         probe: @escaping @MainActor (URL) async throws -> Double?,
         select: @escaping @MainActor (URL, IMHTTPNodePreferenceContext) -> Bool) {
        self.cooldown = cooldown; self.clock = clock; self.context = context
        self.current = current; self.probe = probe; self.select = select
        self.hostRevision = hostRevision
    }

    func start() {
        guard monitor == nil else { return }
        let runID = generation
        monitor = Task { [weak self] in
            do { try await Task<Never, Never>.sleep(nanoseconds: 1_000_000_000) } catch { return }
            while !Task.isCancelled {
                guard let self, self.generation == runID else { return }
                await self.runOnce()
                // 初次 AUTH 可能晚于安装；就绪前每秒核对状态，避免漏掉登录后的首轮测速。
                let interval = min(self.context()?.pollingInterval ?? 1, Double(UInt64.max / 1_000_000_000))
                do { try await Task<Never, Never>.sleep(nanoseconds: UInt64(interval * 1_000_000_000)) }
                catch { return }
            }
        }
    }

    /// 后台暂停保留同轮统计；退出销毁实例后下一账号无法读取这些结果。
    func cancel() {
        generation = UUID()
        monitor?.cancel(); monitor = nil
        isProbing = false
    }

    func runOnce() async {
        guard !isProbing, let snapshot = context(), snapshot.enabled else { return }
        // SDK 可以在测速等待期间独立更新 HTTP Host；旧轮结果不能覆盖该更新。
        // Host 只参与本轮有效性判断，不作为缓存键，择优自身切换仍保留统计与冷却。
        let roundHost = current()
        let roundHostRevision = hostRevision()
        if cacheContext != snapshot {
            cacheContext = snapshot
            rankedSamples = []
            lastSwitch = nil
        }
        isProbing = true
        let runID = generation
        defer { if generation == runID { isProbing = false } }
        do {
            var candidates: [URL] = []
            for node in snapshot.nodes where !candidates.contains(node) {
                if candidates.count == 16 { break }
                candidates.append(node)
            }
            let measured = try await withThrowingTaskGroup(of: (URL, Double?).self) { group in
                for node in candidates {
                    group.addTask { [self] in
                        try await check(runID, snapshot, roundHost: roundHost, hostRevision: roundHostRevision)
                        let latency: Double?
                        do { latency = try await probe(node) }
                        catch is CancellationError { throw CancellationError() }
                        catch { latency = nil }
                        try await check(runID, snapshot, roundHost: roundHost, hostRevision: roundHostRevision)
                        return (node, latency)
                    }
                }
                defer { group.cancelAll() }
                var values: [(URL, Double?)] = []
                for try await value in group { values.append(value) }
                return values
            }
            try check(runID, snapshot, roundHost: roundHost, hostRevision: roundHostRevision)
            var samples = candidates.map { node in
                rankedSamples.first { $0.node == node } ?? IMHTTPNodePreferenceSample(node: node)
            }
            for (node, latency) in measured {
                guard let index = samples.firstIndex(where: { $0.node == node }) else { continue }
                let success = latency.map { $0.isFinite && $0 > 0 } == true
                samples[index].lastSucceeded = success
                if success, let latency {
                    samples[index].successCount += 1
                    samples[index].totalMilliseconds += latency
                }
            }
            // 同轮失败不能靠历史成功恢复为可用；其余沿用成功次数优先、RTT 次优的旧规则。
            let connected = roundHost
            rankedSamples = samples.sorted {
                if $0.lastSucceeded != $1.lastSucceeded { return $0.lastSucceeded }
                if $0.successCount != $1.successCount { return $0.successCount > $1.successCount }
                if $0.averageMilliseconds != $1.averageMilliseconds { return $0.averageMilliseconds < $1.averageMilliseconds }
                if $0.node == connected || $1.node == connected { return $0.node == connected }
                return $0.node.absoluteString < $1.node.absoluteString
            }
            guard let winner = rankedSamples.first, winner.lastSucceeded,
                  let connected, connected != winner.node,
                  lastSwitch.map({ clock() - $0 >= cooldown }) ?? true else { return }
            try check(runID, snapshot, roundHost: roundHost, hostRevision: roundHostRevision)
            // 切换与业务 Host 更新同步完成，不能让 await 窗口跨入另一个会话。
            if select(winner.node, snapshot) { lastSwitch = clock() }
        } catch { /* 请求失败保留当前 Host；取消和导航替换不写入本轮结果。 */ }
    }

    private func check(_ runID: UUID, _ snapshot: IMHTTPNodePreferenceContext, roundHost: URL?, hostRevision: UInt64) throws {
        try Task<Never, Never>.checkCancellation()
        guard generation == runID, context() == snapshot, snapshot.enabled,
              current() == roundHost, self.hostRevision() == hostRevision else { throw CancellationError() }
    }
}
