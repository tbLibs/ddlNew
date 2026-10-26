//
//  IMConnectionCoordinator.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Combine
import Foundation

/// 统一管理登录前连接。首次连接由邀请码页等待，缓存恢复由启动等待页等待。
@MainActor
final class IMConnectionCoordinator: ObservableObject {
    static let shared = IMConnectionCoordinator(
        driver: IMSDKConnectionAdapter(),
        markUsable: { try OSSNavigationStore.shared.markLastUsableEntry(lastLiceseId: $0) }
    )

    @Published private(set) var phase: IMConnectionPhase = .idle
    @Published private(set) var selectedTCPNode: OSSIMTCPNode?

    private let driver: any IMSDKConnectionDriving
    private let markUsable: @MainActor (String) throws -> Void
    /// 所有 await 后都核对本轮标识，防止更换俱乐部后旧请求覆盖新连接。
    private var generation = UUID()
    private var reconnectTask: Task<Void, Never>?
    private var monitorTask: Task<Void, Never>?
    /// 用户 AUTH 开始后，访客重连不能再清理 SDK 用户，交由 SDK 保持已登录连接。
    private var userOwnsConnection = false

    init(driver: any IMSDKConnectionDriving,
         markUsable: @escaping @MainActor (String) throws -> Void) {
        self.driver = driver
        self.markUsable = markUsable
    }

    /// 登录请求发送前应再次查询；页面显示或旧缓存存在均不代表可以发送请求。
    var isLoginReady: Bool {
        !userOwnsConnection && phase == .ready && driver.isConnected
    }

    /// 每个登录异步步骤核对此轮标识，重连后不能提交旧连接领取的密钥。
    var loginConnectionID: UUID? { isLoginReady ? generation : nil }

    func beginUserAuthentication(connectionID: UUID) throws {
        guard loginConnectionID == connectionID else { throw AccountLoginError.connectionChanged }
        userOwnsConnection = true
        monitorTask?.cancel()
        monitorTask = nil
    }

    func isUserConnectionCurrent(_ connectionID: UUID) -> Bool {
        userOwnsConnection && generation == connectionID
    }

    func releaseUserConnection(reconnect: Bool) {
        let owned = userOwnsConnection
        userOwnsConnection = false
        if reconnect, owned { startCachedReconnect() }
    }

    /// 新邀请码、更换俱乐部或主动重试时，停止旧恢复任务和 SDK 的自动重连。
    func reset() {
        userOwnsConnection = false
        generation = UUID()
        reconnectTask?.cancel()
        reconnectTask = nil
        monitorTask?.cancel()
        monitorTask = nil
        driver.reset()
        phase = .idle
        selectedTCPNode = nil
    }

    /// TCP/ECDH 成功后将本地固定 tenantCode 写入 SDK，不请求系统配置。
    func connectForLogin(plan: OSSConnectionPlan) async throws {
        reset()
        let runID = generation
        do {
            try await completeConnection(plan: plan, runID: runID)
            startMonitoring(runID: runID)
        } catch {
            if generation == runID {
                driver.reset()
                phase = error is CancellationError ? .idle : .failed("连接初始化失败，请重试")
            }
            throw error
        }
    }

    /// 缓存启动保留启动等待页，后台尝试缓存节点；失败后重新导航并退避重试。
    func startCachedReconnect() {
        guard !userOwnsConnection else { return }
        guard let lastLiceseId = OSSNavigationStore.shared.lastUsableLiceseId() else { return }
        reset()
        let runID = generation
        phase = .connecting
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            var attempt = 0
            defer { if self.generation == runID { self.reconnectTask = nil } }
            while !Task.isCancelled, self.generation == runID {
                do {
                    let plan = try await self.reconnectPlan(lastLiceseId: lastLiceseId, refresh: attempt > 0, runID: runID)
                    try await self.completeConnection(plan: plan, runID: runID)
                    self.startMonitoring(runID: runID)
                    return
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled, self.generation == runID else { return }
                    self.driver.reset()
                    self.selectedTCPNode = nil
                    self.phase = .failed("连接失败，正在自动重试…")
                    debugPrint("[IM重连] 第 \(attempt + 1) 次初始化失败：\(error)")
                    let delay = UInt64(1 << min(attempt, 4))
                    attempt += 1
                    do {
                        try await Task<Never, Never>.sleep(nanoseconds: delay * 1_000_000_000)
                    } catch { return }
                    guard !Task.isCancelled, self.generation == runID else { return }
                    self.phase = .connecting
                }
            }
        }
    }

    /// 启动页等待本轮恢复结果；连接失败时交由启动流程返回邀请码页。
    func waitForLoginReadiness() async throws {
        while !isLoginReady {
            try Task<Never, Never>.checkCancellation()
            if case .failed = phase {
                throw IMConnectionError.connectionLost
            }
            try await Task<Never, Never>.sleep(nanoseconds: 250_000_000)
        }
        try Task<Never, Never>.checkCancellation()
    }

    private func completeConnection(plan: OSSConnectionPlan, runID: UUID) async throws {
        try check(runID)
        phase = .connecting
        let node = try await driver.connect(plan)
        try check(runID)
        selectedTCPNode = node
        guard driver.isConnected else { throw IMConnectionError.connectionLost }
        driver.applyTenantCode(LocalSDKSettings.tenantCode)
        #if DEBUG
        debugPrint("[SDK租户] tenantCode=\(LocalSDKSettings.tenantCode)")
        #endif
        try markUsable(plan.lastLiceseId)
        phase = .ready
        debugPrint("[IM连接] 正式 TCP/ECDH 就绪，租户参数与功能规则使用本地固定值")
    }

    private func reconnectPlan(lastLiceseId: String, refresh: Bool, runID: UUID) async throws -> OSSConnectionPlan {
        try check(runID)
        let winner = try await OSSNodeRaceCoordinator.race(
            lastLiceseId: lastLiceseId, useDNS1Cache: !refresh
        )
        try check(runID)
        try OSSNavigationStore.shared.save(winner, lastLiceseId: lastLiceseId)
        return try OSSConnectionBootstrap.shared.prepare(requireFresh: false, probedTCPAddress: winner.node.urlString)
    }

    /// SDK 仍拥有长连接的断线通知；定期核对实际状态，让 UI 的就绪标志及时失效。
    private func startMonitoring(runID: UUID) {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task<Never, Never>.sleep(nanoseconds: 1_000_000_000) }
                catch { return }
                guard let self, self.generation == runID else { return }
                if !self.driver.isConnected {
                    self.startCachedReconnect()
                    return
                }
            }
        }
    }

    private func check(_ runID: UUID) throws {
        try Task<Never, Never>.checkCancellation()
        guard generation == runID else { throw CancellationError() }
    }
}
