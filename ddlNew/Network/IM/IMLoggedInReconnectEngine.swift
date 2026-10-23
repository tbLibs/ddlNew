import Foundation

nonisolated struct IMReconnectSession: Equatable, Sendable {
    let userUID: String
    let lastLiceseId: String
}

/// 刷新结果携带本轮探测凭据；旧五路返回的地址仍必须完成业务 TCP/ECDH。
nonisolated struct IMReconnectNodes: Sendable {
    let nodes: [OSSLegacyEndpoint]
    var probedNode: OSSLegacyEndpoint? = nil
}

/// 登录后的竞速只探测临时 ECDH Socket，正式连接和 AUTH 仍由 SDK 执行。
@MainActor
final class IMLoggedInReconnectEngine {
    typealias Completion = (OSSLegacyEndpoint?, String?) -> Void
    private let session: IMReconnectSession
    private let isCurrentSession: @MainActor (IMReconnectSession) -> Bool
    private let cachedNodes: @MainActor () -> [OSSLegacyEndpoint]
    private let refreshNodes: @MainActor () async throws -> IMReconnectNodes
    private let probe: @MainActor (OSSLegacyEndpoint) async throws -> Bool
    private let clock: @MainActor () -> TimeInterval
    /// 由调用方给出完整链路时限，必须早于 SDK 的兜底截止。
    private let timeout: TimeInterval
    private let cooldown: TimeInterval
    private var lastRefresh: TimeInterval?
    private var generation = UUID()
    private var work: Task<Void, Never>?
    private var timer: Task<Void, Never>?
    private var completion: Completion?

    init(session: IMReconnectSession, timeout: TimeInterval = 55, cooldown: TimeInterval = 60,
         clock: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         isCurrentSession: @escaping @MainActor (IMReconnectSession) -> Bool,
         cachedNodes: @escaping @MainActor () -> [OSSLegacyEndpoint],
         refreshNodes: @escaping @MainActor () async throws -> IMReconnectNodes,
         probe: @escaping @MainActor (OSSLegacyEndpoint) async throws -> Bool) {
        self.session = session; self.timeout = timeout; self.cooldown = cooldown
        self.clock = clock; self.isCurrentSession = isCurrentSession
        self.cachedNodes = cachedNodes; self.refreshNodes = refreshNodes; self.probe = probe
    }

    func begin(completion: @escaping Completion) {
        cancel()
        guard isCurrentSession(session) else { return }
        self.completion = completion
        let runID = generation
        timer = Task { [weak self] in
            do { try await Task<Never, Never>.sleep(nanoseconds: UInt64((self?.timeout ?? 55) * 1_000_000_000)) }
            catch { return }
            self?.finish(runID, node: nil, failure: "tcp_probe_timeout")
        }
        work = Task { [weak self] in
            guard let self else { return }
            do {
                if let winner = try await firstReachable(cachedNodes(), runID: runID) {
                    finish(runID, node: winner, failure: nil)
                    return
                }
                try check(runID)
                let now = clock()
                if let lastRefresh, now - lastRefresh < cooldown {
                    finish(runID, node: nil, failure: "navigation_refresh_cooldown")
                    return
                }
                // 失败和取消也计入冷却；每一轮到这里最多一次。
                lastRefresh = now
                let refreshed = try await refreshNodes()
                try check(runID)
                // 只复用本轮已探测且仍属于返回列表的节点；不能按全局DNS1开关跳过旧源探测。
                let winner: OSSLegacyEndpoint?
                if let probed = refreshed.probedNode, refreshed.nodes.contains(probed) { winner = probed }
                else { winner = try await firstReachable(refreshed.nodes, runID: runID) }
                finish(runID, node: winner, failure: winner == nil ? "tcp_nodes_unreachable" : nil)
            } catch is CancellationError { }
            catch { finish(runID, node: nil, failure: "navigation_refresh_failed") }
        }
    }

    func cancel() {
        generation = UUID()
        completion = nil
        work?.cancel(); work = nil
        timer?.cancel(); timer = nil
    }

    private func firstReachable(_ nodes: [OSSLegacyEndpoint], runID: UUID) async throws -> OSSLegacyEndpoint? {
        try check(runID)
        return try await withThrowingTaskGroup(of: OSSLegacyEndpoint?.self) { group in
            var unique: [OSSLegacyEndpoint] = []
            for node in nodes.prefix(16) where !unique.contains(node) {
                unique.append(node)
                group.addTask { [self] in
                    try await check(runID)
                    do {
                        let success = try await probe(node)
                        try await check(runID)
                        return success ? node : nil
                    } catch is CancellationError { throw CancellationError() }
                    catch {
                        try await check(runID)
                        return nil // 单节点超时/握手失败不能取消其他候选。
                    }
                }
            }
            defer { group.cancelAll() }
            for try await node in group { if let node { return node } }
            return nil
        }
    }

    private func check(_ runID: UUID) throws {
        try Task<Never, Never>.checkCancellation()
        guard generation == runID, completion != nil, isCurrentSession(session) else {
            throw CancellationError()
        }
    }

    private func finish(_ runID: UUID, node: OSSLegacyEndpoint?, failure: String?) {
        guard generation == runID, let callback = completion else { return }
        let current = isCurrentSession(session)
        cancel()
        if current { callback(node, failure) }
    }
}
