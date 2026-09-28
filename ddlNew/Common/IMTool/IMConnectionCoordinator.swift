//
//  IMConnectionCoordinator.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Combine
import Foundation

/// 初始化进度同时供邀请码页和登录页读取；就绪不等于账号已登录。
enum IMConnectionPhase: Equatable {
    case idle
    case connecting
    case fetchingConfiguration
    case ready
    case failed(String)

    var message: String {
        switch self {
        case .idle: return "连接尚未准备"
        case .connecting: return "正在恢复 TCP/ECDH 连接…"
        case .fetchingConfiguration: return "连接已建立，正在获取系统配置…"
        case .ready: return "连接已就绪"
        case .failed(let message): return message
        }
    }

    var isBusy: Bool {
        self == .connecting || self == .fetchingConfiguration
    }
}

/// 统一管理登录前连接。首次连接由邀请码页等待，缓存恢复由启动等待页等待。
@MainActor
final class IMConnectionCoordinator: ObservableObject {
    static let shared = IMConnectionCoordinator(
        driver: IMSDKConnectionAdapter(),
        fetchConfiguration: { try await SystemConfigService.shared.fetchAndCache(for: $0) },
        markUsable: { try OSSNavigationStore.shared.markLastUsableEntry(lastLiceseId: $0) }
    )

    @Published private(set) var phase: IMConnectionPhase = .idle
    /// 仅持有本次连接完成后获取的配置，不用启动时的历史配置冒充就绪。
    @Published private(set) var configuration: SystemConfigRecord?
    @Published private(set) var selectedTCPNode: OSSIMTCPNode?

    private let driver: any IMSDKConnectionDriving
    private let fetchConfiguration: @MainActor (OSSConnectionPlan) async throws -> SystemConfigRecord
    private let markUsable: @MainActor (String) throws -> Void
    /// 所有 await 后都核对本轮标识，防止更换俱乐部后旧请求覆盖新连接。
    private var generation = UUID()
    private var reconnectTask: Task<Void, Never>?
    private var monitorTask: Task<Void, Never>?

    init(driver: any IMSDKConnectionDriving,
         fetchConfiguration: @escaping @MainActor (OSSConnectionPlan) async throws -> SystemConfigRecord,
         markUsable: @escaping @MainActor (String) throws -> Void) {
        self.driver = driver
        self.fetchConfiguration = fetchConfiguration
        self.markUsable = markUsable
    }

    /// 登录请求发送前应再次查询；页面显示或旧缓存存在均不代表可以发送请求。
    var isLoginReady: Bool {
        phase == .ready && driver.isConnected && configuration?.isValidForLogin == true
    }

    /// 每个登录异步步骤核对此轮标识，重连后不能提交旧连接领取的密钥。
    var loginConnectionID: UUID? { isLoginReady ? generation : nil }

    /// 新邀请码、更换俱乐部或主动重试时，停止旧恢复任务和 SDK 的自动重连。
    func reset() {
        generation = UUID()
        reconnectTask?.cancel()
        reconnectTask = nil
        monitorTask?.cancel()
        monitorTask = nil
        driver.reset()
        phase = .idle
        configuration = nil
        selectedTCPNode = nil
    }

    /// 首次加入必须按 TCP/ECDH → 系统配置 → SDK 租户配置 → 保存可用入口的顺序完成。
    func connectForLogin(plan: OSSConnectionPlan) async throws -> SystemConfigRecord {
        reset()
        let runID = generation
        do {
            let result = try await completeConnection(plan: plan, runID: runID)
            startMonitoring(runID: runID)
            return result
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
                    _ = try await self.completeConnection(plan: plan, runID: runID)
                    self.startMonitoring(runID: runID)
                    return
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled, self.generation == runID else { return }
                    self.driver.reset()
                    self.configuration = nil
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

    /// 启动页持续等待，不把历史配置或单次探测成功当作登录链路已经就绪。
    func waitForLoginReadiness() async throws {
        while !isLoginReady {
            try Task<Never, Never>.checkCancellation()
            try await Task<Never, Never>.sleep(nanoseconds: 250_000_000)
        }
        try Task<Never, Never>.checkCancellation()
    }

    private func completeConnection(plan: OSSConnectionPlan, runID: UUID) async throws -> SystemConfigRecord {
        try check(runID)
        configuration = nil
        phase = .connecting
        let node = try await driver.connect(plan)
        try check(runID)
        selectedTCPNode = node
        phase = .fetchingConfiguration
        debugPrint("[IM连接] 正式 TCP/ECDH 成功，开始获取系统配置")

        let result = try await fetchConfiguration(plan)
        try check(runID)
        guard result.isValidForLogin, driver.isConnected else { throw IMConnectionError.connectionLost }
        driver.apply(result)
        // 整条初始化链路成功后才保存 lastLiceseId，不能由单次握手或历史配置提前确认。
        try markUsable(plan.lastLiceseId)
        configuration = result
        phase = .ready
        debugPrint("[IM连接] 登录链路已就绪，验证码渠道：\(result.captchaChannel)")
        return result
    }

    private func reconnectPlan(lastLiceseId: String, refresh: Bool, runID: UUID) async throws -> OSSConnectionPlan {
        try check(runID)
        if !refresh, let cached = try? OSSConnectionBootstrap.shared.prepare(requireFresh: false) {
            return cached
        }
        let clientIP = await PublicIPResolver.resolve()
        try check(runID)
        let winner = try await OSSNodeRaceCoordinator.race(
            lastLiceseId: lastLiceseId,
            credentials: OSSAuthCredentials(signingKeyID: DirectDecodeKeyId, signingKeySecret: DirectDecodeKeySecret),
            clientIP: clientIP
        )
        try check(runID)
        try OSSNavigationStore.shared.save(winner, lastLiceseId: lastLiceseId)
        return try OSSConnectionBootstrap.shared.prepare(requireFresh: false)
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
