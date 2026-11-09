import Foundation
import NoaChatCore
import UIKit

/// 登录期间唯一的 SDK 重连竞速入口；不重新初始化 SDK，也不写登录凭据。
@MainActor
final class IMLoggedInReconnectCoordinator {
    static let shared = IMLoggedInReconnectCoordinator()
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }
    private var socket: NoaIMSocketManager { NoaIMSocketManager.sharedTool() }
    private var engine: IMLoggedInReconnectEngine?
    private var quality: IMNetworkQualityEngine?
    private var httpPreference: IMHTTPNodePreferenceEngine?
    private var foregroundGate = IMForegroundSessionGate(isInBackground: false)
    private var reconnectRacing = false
    private var messageProbeVisible = false
    private let messageProbe = MessageConnectivityProbe()
    private var observers: [NSObjectProtocol] = []
    private var installation = UUID()
    private init() {}

    /// 在 SDK 用户配置完成后安装，初次 AUTH 期间断线也能选取节点。
    func start(userUID: String, lastLiceseId: String) {
        stop()
        guard !userUID.isEmpty, !lastLiceseId.isEmpty else { return }
        let session = IMReconnectSession(userUID: userUID, lastLiceseId: lastLiceseId)
        let installID = installation
        foregroundGate = IMForegroundSessionGate(isInBackground: UIApplication.shared.applicationState == .background)
        engine = IMLoggedInReconnectEngine(session: session,
            // 缓存探测与DNS1主/备/BIN共享业务截止，早于SDK的40秒兜底。
            timeout: 35,
            isCurrentSession: { [weak self] in self?.owns($0, installation: installID) == true },
            cachedNodes: {
                guard let cache = try? OSSNavigationStore.shared.load(), cache.lastLiceseId == lastLiceseId,
                      cache.source == .dns1 else {
                    IMReconnectTrace.log("event=reconnect_cache candidates=0")
                    return []
                }
                IMReconnectTrace.log("event=reconnect_cache candidates=\(cache.tcpEndpoints.count) probeLimit=16")
                return cache.tcpEndpoints.map { OSSLegacyEndpoint(host: $0.ip, port: UInt16($0.port)) }
            },
            refreshNodes: { [weak self] in
                guard let self else { throw CancellationError() }
                IMReconnectTrace.log("event=reconnect_refresh reason=no_cached_winner")
                return try await self.refreshNodes(session, installation: installID, qualityOnly: false)
            },
            probe: { [weak self] node in
                guard let self, self.owns(session, installation: installID) else { throw CancellationError() }
                let waiter = IMHandshakeWaiter()
                return try await waiter.run(timeout: 4) {
                    self.sdk.probeECDHConnectivity(withHost: node.host, port: node.port, timeout: 4, type: 0) { success, _ in
                        Task { @MainActor in waiter.finish(.success(success)) }
                    }
                }
            })
        // SDK 回调来自内部串行队列，业务状态统一切回 MainActor。
        socket.raceTcpNodeBlock = { [weak self] completion in
            let round = NoaIMSocketManager.sharedTool().tcpRaceSequence
            Task { @MainActor [weak self] in
                guard let self, self.owns(session, installation: installID) else { return }
                // 断线竞速先抢占质量检测，不能同时更新节点或刷新导航。
                self.reconnectRacing = true
                self.quality?.cancel()
                self.httpPreference?.cancel()
                IMReconnectTrace.$round.withValue(round) {
                    self.engine?.begin { node, reason in
                        IMReconnectTrace.log("event=reconnect_selection result=\(reason ?? "probe_success")")
                        completion(node?.host, node.map { Int($0.port) } ?? 0, reason)
                    }
                }
            }
        }
        socket.cancelTcpNodeRaceBlock = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.installation == installID else { return }
                self.engine?.cancel()
                self.reconnectRacing = false
                if UIApplication.shared.applicationState == .active {
                    self.quality?.start()
                    self.httpPreference?.start()
                }
            }
        }
        quality = IMNetworkQualityEngine(
            eligible: { [weak self] in self?.qualityEligible(session, installation: installID) == true },
            nodes: {
                guard let cache = try? OSSNavigationStore.shared.load(), cache.lastLiceseId == lastLiceseId else { return [] }
                return cache.tcpEndpoints.compactMap { endpoint in
                    guard endpoint.port > 0, endpoint.port <= Int32(UInt16.max) else { return nil }
                    return OSSLegacyEndpoint(host: endpoint.ip, port: UInt16(endpoint.port))
                }
            },
            current: { [weak self] in
                guard let self else { return nil }
                let host = self.socket.socketHostValue()
                guard !host.isEmpty, let port = UInt16(exactly: self.socket.socketPortValue()), port > 0 else { return nil }
                return OSSLegacyEndpoint(host: host, port: port)
            },
            refresh: { [weak self] in
                guard let self else { throw CancellationError() }
                return try await self.refreshNodes(session, installation: installID, qualityOnly: true).nodes
            },
            probe: { [weak self] node in
                guard let self, self.qualityEligible(session, installation: installID) else { throw CancellationError() }
                let started = ProcessInfo.processInfo.systemUptime
                let waiter = IMHandshakeWaiter()
                let succeeded = try await waiter.run(timeout: 11) {
                    self.sdk.probeECDHConnectivity(withHost: node.host, port: node.port, timeout: 10, type: 1) { success, _ in
                        Task { @MainActor in waiter.finish(.success(success)) }
                    }
                }
                guard self.qualityEligible(session, installation: installID) else { throw CancellationError() }
                return succeeded ? (ProcessInfo.processInfo.systemUptime - started) * 1000 : nil
            },
            switchNode: { [weak self] node in
                guard let self, self.qualityEligible(session, installation: installID) else { return false }
                return await withCheckedContinuation { continuation in
                    self.socket.switchAuthenticatedSocket(host: node.host, port: node.port,
                        userID: session.userUID, liceseId: session.lastLiceseId) { accepted in
                        // 接受切换不代表新连接 AUTH 成功，业务就绪仍由原认证服务判断。
                        continuation.resume(returning: accepted)
                    }
                }
            })
        httpPreference = IMHTTPNodePreferenceEngine(
            context: { [weak self] in self?.httpContext(session, installation: installID) },
            current: {
                guard let host = OSSConnectionBootstrap.shared.current?.apiHost else { return nil }
                return IMHTTPNodePreferenceURL.base(host.absoluteString)
            },
            hostRevision: { OSSConnectionBootstrap.shared.httpHostRevision },
            probe: { node in
                try await IMHTTPNodePreferenceProbe.measure(node, path: NetworkPath.httpNodePreference)
            },
            select: { [weak self] node, context in
                guard let self, self.httpContext(session, installation: installID) == context,
                      OSSConnectionBootstrap.shared.current?.lastLiceseId == session.lastLiceseId else { return false }
                // SDK 下次请求和业务 API／头像／上传共用同一 Host，不重配用户、Token 或数据库。
                self.sdk.configApiHost(node.absoluteString)
                self.sdk.configSDKSsoInfo(session.lastLiceseId)
                OSSConnectionBootstrap.shared.updateHTTPHost(node.absoluteString)
                SessionMaintenanceCoordinator.shared.refreshAfterNodeChange()
                return true
            })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.installation == installID else { return }
                    #if DEBUG
                    NSLog("[IM掉线] event=app_background")
                    #endif
                    self.foregroundGate.enteredBackground()
                    self.quality?.cancel()
                    self.httpPreference?.cancel()
                }
            })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.owns(session, installation: installID),
                          self.foregroundGate.takeForegroundCheck() else { return }
                    #if DEBUG
                    NSLog("[IM掉线] event=app_foreground")
                    #endif
                    // 检查当前正式 Socket；SDK 自己处理 PING 超时和重连，不能建立访客连接。
                    self.socket.verifyConnectionOnForeground()
                }
            })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.owns(session, installation: installID) else { return }
                    self.quality?.start()
                    self.httpPreference?.start()
                }
            })
        if UIApplication.shared.applicationState == .active {
            quality?.start()
            httpPreference?.start()
        }
    }

    /// 先撤销回调和竞速，退出后迟到的结果不能更新下一次登录。
    func stop() {
        installation = UUID()
        messageProbe.cancel()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        quality?.cancel(); quality = nil
        httpPreference?.cancel(); httpPreference = nil
        reconnectRacing = false
        socket.raceTcpNodeBlock = nil
        socket.cancelTcpNodeRaceBlock = nil
        engine?.cancel()
        engine = nil
    }

    /// 消息页探测与质量择优互斥；它只验证当前节点，不运行全节点竞速。
    func setMessageProbeVisible(_ visible: Bool) {
        guard messageProbeVisible != visible else { return }
        messageProbeVisible = visible
        if visible { quality?.cancel() }
        else {
            messageProbe.cancel()
            if UIApplication.shared.applicationState == .active { quality?.start() }
        }
    }

    func probeMessageConnection() async {
        let installID = installation
        let session = IMReconnectSession(userUID: sdk.myUserID(), lastLiceseId: sdk.currentLiceseId())
        let connection = socket.gcdSocket
        let revision = IMUserAuthenticationService.shared.connectionRevision
        let host = socket.socketHostValue()
        guard let port = UInt16(exactly: socket.socketPortValue()), port > 0, !host.isEmpty else { return }
        await messageProbe.run(isCurrent: { [weak self] in
            guard let self else { return false }
            return self.messageProbeVisible && !self.reconnectRacing && self.quality?.isProbing != true
                && UIApplication.shared.applicationState == .active
                && self.owns(session, installation: installID) && self.sdk.isUserAuthenticated()
                && self.socket.gcdSocket === connection
                && IMUserAuthenticationService.shared.connectionRevision == revision
        }, probe: {
            let waiter = IMHandshakeWaiter()
            return try await waiter.run(timeout: 3) {
                self.sdk.probeECDHConnectivity(withHost: host, port: port, timeout: 3, type: 1) { success, _ in
                    Task { @MainActor in waiter.finish(.success(success)) }
                }
            }
        }, reconnect: {
            self.socket.reconnectIfCurrentSocket(connection, userID: session.userUID, liceseId: session.lastLiceseId)
        })
    }

    private func qualityEligible(_ session: IMReconnectSession, installation: UUID) -> Bool {
        guard owns(session, installation: installation), !reconnectRacing, !messageProbeVisible,
              UIApplication.shared.applicationState == .active, sdk.isUserAuthenticated(),
              let snapshot = try? OSSNavigationStore.shared.load(), snapshot.lastLiceseId == session.lastLiceseId else { return false }
        return snapshot.configuration?.enableNetworkDetect == true
    }

    private func httpContext(_ session: IMReconnectSession, installation: UUID) -> IMHTTPNodePreferenceContext? {
        guard owns(session, installation: installation), !reconnectRacing,
              UIApplication.shared.applicationState == .active, sdk.isUserAuthenticated(),
              let record = try? OSSNavigationStore.shared.loadSSOInfo(),
              let snapshot = try? record.snapshot(), snapshot.lastLiceseId == session.lastLiceseId else { return nil }
        return IMHTTPNodePreferenceContext(userUID: session.userUID, lastLiceseId: session.lastLiceseId,
            navigationGeneration: "\(snapshot.savedAt.timeIntervalSince1970):\(record.ossRacingModel.version)",
            enabled: record.ossRacingModel.isMergeVersion,
            interval: TimeInterval(record.ossRacingModel.pingIntervalSecond),
            nodes: record.ossRacingModel.httpArr.compactMap { IMHTTPNodePreferenceURL.base($0.ip) })
    }

    private func refreshNodes(_ session: IMReconnectSession, installation: UUID,
                              qualityOnly: Bool) async throws -> IMReconnectNodes {
        func check() throws {
            try Task<Never, Never>.checkCancellation()
            guard owns(session, installation: installation),
                  !qualityOnly || qualityEligible(session, installation: installation) else { throw CancellationError() }
        }
        try check()
        let winner = try await OSSNodeRaceCoordinator.race(lastLiceseId: session.lastLiceseId)
        try check()
        try OSSNavigationStore.shared.save(winner, lastLiceseId: session.lastLiceseId)
        let plan = try OSSConnectionBootstrap.shared.prepare(
            requireFresh: false, probedTCPAddress: winner.node.urlString
        )
        guard plan.lastLiceseId == session.lastLiceseId else { throw CancellationError() }
        // 更新导航沿用重连已有行为；不调用访客连接或重新配置用户、Token、数据库。
        sdk.configApiHost(plan.apiHost?.absoluteString ?? "")
        NoaIMHttpManager.shared().messagePushHTTPHosts = plan.httpCandidates.map(\.absoluteString)
        SessionMaintenanceCoordinator.shared.refreshAfterNodeChange()
        return IMReconnectNodes(
            nodes: plan.tcpCandidates.map { OSSLegacyEndpoint(host: $0.host, port: $0.port) },
            probedNode: plan.probedTCPNode.map { OSSLegacyEndpoint(host: $0.host, port: $0.port) }
        )
    }

    private func owns(_ session: IMReconnectSession, installation: UUID) -> Bool {
        self.installation == installation && socket.isCanReconnect
            && sdk.myUserID() == session.userUID && sdk.currentLiceseId() == session.lastLiceseId
    }
}
