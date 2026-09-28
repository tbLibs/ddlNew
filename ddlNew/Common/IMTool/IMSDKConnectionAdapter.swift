//
//  IMSDKConnectionAdapter.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation
import NoaChatCore

/// SDK 与连接流程之间的边界，便于用替身验证连接顺序和取消行为。
@MainActor
protocol IMSDKConnectionDriving: AnyObject {
    var isConnected: Bool { get }
    func reset()
    func connect(_ plan: OSSConnectionPlan) async throws -> OSSIMTCPNode
    func apply(_ configuration: SystemConfigRecord)
}

/// TCP/ECDH 初始化失败；不包含密钥或账号密码。
enum IMConnectionError: Error {
    case missingTCPNodes
    case allProbesFailed
    case handshakeFailed
    case timedOut
    case connectionLost
}

/// 临时探测选节点，正式 Socket 再握手；两者不能混作同一条连接。
@MainActor
final class IMSDKConnectionAdapter: IMSDKConnectionDriving {
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }
    private var socket: NoaIMSocketManager { NoaIMSocketManager.sharedTool() }
    /// 切换入口时使准备、探测及正式握手的旧回调全部失效。
    private var generation = UUID()
    private var waiters: [UUID: IMHandshakeWaiter] = [:]
    private var selectedNode: OSSIMTCPNode?

    var isConnected: Bool {
        guard let node = selectedNode else { return false }
        return socket.currentSocketConnectStatus() && socket.isExchangeEcdhKeySuccess()
            && socket.socketHostValue() == node.host && socket.socketPortValue() == Int(node.port)
    }

    func reset() {
        generation = UUID()
        selectedNode = nil
        let pending = Array(waiters.values)
        waiters.removeAll()
        pending.forEach { $0.finish(.failure(CancellationError())) }
        socket.prepareForConnectionInitialization()
        sdk.configSDKTenantCode("")
    }

    func connect(_ plan: OSSConnectionPlan) async throws -> OSSIMTCPNode {
        try Task<Never, Never>.checkCancellation()
        guard !plan.tcpCandidates.isEmpty else { throw IMConnectionError.missingTCPNodes }
        let runID = generation

        // 必须等待 SDK 清理完旧 Socket，不能只调用异步清理方法后立即配置新 Host。
        let preparation = IMHandshakeWaiter()
        try await wait(preparation, timeout: 5) {
            self.socket.prepareForConnectionInitialization {
                Task { @MainActor in preparation.finish(.success(true)) }
            }
        }
        try check(runID)

        let options = NoaIMSDKApiOptions()
        options.imApi = plan.apiHost.absoluteString
        options.imOrgName = businessOrgName
        sdk.configSDKApi(with: options)
        sdk.configSDKLiceseId(plan.lastLiceseId)
        sdk.configSDKSsoInfo(plan.lastLiceseId)
        sdk.configSDKTenantCode("")
        sdk.configSDKCaptchaChannel(1)
        // 这里只建立未登录连接，不装载演示账号，也不初始化用户数据库。
        sdk.clearMyUserInfo()
        socket.clearUserInfo()

        let node = try await firstReachableNode(in: plan.tcpCandidates)
        try check(runID)
        selectedNode = node
        debugPrint("[IM连接] ECDH 探测首胜：\(node.host):\(node.port)，开始正式连接")

        let handshake = IMHandshakeWaiter()
        try await wait(handshake, timeout: 20) {
            // 先监听后连接，避免快速成功的通知丢失。成功还要核对正式 Socket 的 ECDH 状态。
            handshake.observeSocket(success: { [weak self] in self?.isConnected == true })
            let host = NoaIMSocketHostOptions()
            host.socketHost = node.host
            host.socketPort = Int(node.port)
            host.socketOrgName = businessOrgName
            self.socket.configureSocketHost(host)
        }
        try check(runID)
        guard isConnected else { throw IMConnectionError.connectionLost }
        return node
    }

    func apply(_ configuration: SystemConfigRecord) {
        sdk.configSDKTenantCode(configuration.tenantCode)
        sdk.configSDKCaptchaChannel(configuration.captchaChannel)
    }

    private func check(_ runID: UUID) throws {
        try Task<Never, Never>.checkCancellation()
        guard generation == runID else { throw CancellationError() }
    }

    /// 与旧项目一致：候选并发探测，首个完成真实 ECDH 的节点获胜。
    private func firstReachableNode(in nodes: [OSSIMTCPNode]) async throws -> OSSIMTCPNode {
        try await withThrowingTaskGroup(of: OSSIMTCPNode?.self) { group in
            for node in nodes {
                group.addTask { [self] in
                    try Task<Never, Never>.checkCancellation()
                    return try await probe(node) ? node : nil
                }
            }
            for try await node in group {
                if let node {
                    group.cancelAll()
                    return node
                }
            }
            throw IMConnectionError.allProbesFailed
        }
    }

    private func probe(_ node: OSSIMTCPNode) async throws -> Bool {
        let waiter = IMHandshakeWaiter()
        // SDK 没有取消临时探测的接口；Swift 等待可立即取消，底层临时 Socket 最多存活 10 秒。
        do {
            try await wait(waiter, timeout: 12) {
                self.sdk.probeECDHConnectivity(withHost: node.host, port: node.port, timeout: 10, type: 0) { success, status in
                    let statusValue = status.rawValue
                    Task { @MainActor in
                        if !success {
                            debugPrint("[IM探测] \(node.host):\(node.port) 失败，状态：\(statusValue)")
                        }
                        waiter.finish(.success(success))
                    }
                }
            }
            return true
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return false
        }
    }

    private func wait(_ waiter: IMHandshakeWaiter, timeout: TimeInterval,
                      start: @MainActor () -> Void) async throws {
        let id = UUID()
        waiters[id] = waiter
        defer { waiters[id] = nil }
        let success = try await waiter.run(timeout: timeout, start: start)
        guard success else { throw IMConnectionError.handshakeFailed }
    }
}

/// 回调、通知、超时、取消共享一次性完成入口；迟到回调不能重复恢复 continuation。
@MainActor
private final class IMHandshakeWaiter {
    private var continuation: CheckedContinuation<Bool, Error>?
    private var completed: Result<Bool, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    func run(timeout: TimeInterval, start: @MainActor () -> Void) async throws -> Bool {
        try await withTaskCancellationHandler {
            try Task<Never, Never>.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                if let completed { continuation.resume(with: completed); return }
                self.continuation = continuation
                timeoutTask = Task { [weak self] in
                    do {
                        try await Task<Never, Never>.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        self?.finish(.failure(IMConnectionError.timedOut))
                    } catch { /* 取消超时任务不代表连接失败。 */ }
                }
                start()
            }
        } onCancel: {
            Task { @MainActor in self.finish(.failure(CancellationError())) }
        }
    }

    func observeSocket(success: @escaping @MainActor () -> Bool) {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: Notification.Name("socketECDHDidConnectSuccese"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard success() else { return }
                self?.finish(.success(true))
            }
        })
        observers.append(center.addObserver(forName: Notification.Name("socketECDHDidConnectFailure"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.finish(.failure(IMConnectionError.handshakeFailed)) }
        })
    }

    func finish(_ result: Result<Bool, Error>) {
        guard completed == nil else { return }
        completed = result
        timeoutTask?.cancel()
        timeoutTask = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        let pending = continuation
        continuation = nil
        pending?.resume(with: result)
    }
}
