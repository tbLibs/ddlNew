//
//  OSSNodeRaceCoordinator.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation

/// OSS Auth 请求签名所需的旧协议密钥。
struct OSSAuthCredentials: Sendable {
    /// 签名密钥标识，对应旧项目 DirectDecodeKeyId。
    let signingKeyID: String
    /// 签名密钥内容，对应旧项目 DirectDecodeKeySecret。
    let signingKeySecret: String
}

/// 竞速首胜结果，保留 DNS 或降级来源、OSS 地址和解密后的导航数据。
struct OSSRaceWinner: Sendable {
    /// 提供获胜候选的 DNS 来源。
    let source: DNSHostSource
    /// 完成 OSS Auth 的节点地址。
    let node: DNSResolvedHost
    /// 后续 IM 连接可使用的 TCP/HTTP 导航节点。
    let navigation: OSSNavigationResult
}

/// 五路 OSS Auth 竞速的入口参数和结果错误。
enum OSSNodeRaceError: Error {
    /// 邀请码（liceseId）为空。
    case missingLastLiceseId
    /// 签名常量缺失。
    case missingCredentials
    /// 五路 DNS 和导航降级均未得到有效响应。
    case allSourcesFailed
    /// 导航总时限已到，取消剩余解析和请求。
    case timedOut
}

/// 五路 DNS 同时开始；每一路按候选顺序尝试 OSS TCP，首个通过导航校验的节点获胜。
enum OSSNodeRaceCoordinator {
    static func race(
        lastLiceseId: String,
        credentials: OSSAuthCredentials,
        clientIP: String = ""
    ) async throws -> OSSRaceWinner {
        guard !lastLiceseId.isEmpty else { throw OSSNodeRaceError.missingLastLiceseId }
        guard !credentials.signingKeyID.isEmpty, !credentials.signingKeySecret.isEmpty else {
            throw OSSNodeRaceError.missingCredentials
        }

        // 各阶段共享总时限；避免持续小量响应或长候选列表无限拖延登录。
        return try await OSSRaceDeadline.run(seconds: 30) {
            try await raceWithFallback(lastLiceseId: lastLiceseId, credentials: credentials, clientIP: clientIP)
        }
    }

    private static func raceWithFallback(lastLiceseId: String, credentials: OSSAuthCredentials,
                                         clientIP: String) async throws -> OSSRaceWinner {
        if let winner = try? await OSSRaceDeadline.run(seconds: 9, operation: {
            try await withThrowingTaskGroup(of: OSSRaceWinner?.self) { group in
                for source in DNSHostSource.primarySources {
                    group.addTask {
                        await raceSource(source, lastLiceseId: lastLiceseId,
                                         credentials: credentials, clientIP: clientIP)
                    }
                }
                defer { group.cancelAll() }
                for try await winner in group { if let winner { return winner } }
                throw OSSNodeRaceError.allSourcesFailed
            }
        }) { return winner }
        try Task<Never, Never>.checkCancellation()

        // 五路失败后依次走旧解析器、缓存及内置 TCP 地址、加密 OSS HTTP 文件。
        if let winner = try? await OSSRaceDeadline.run(seconds: 8, operation: {
            let hosts = await AliDNSAsyncBridge.resolve(using: HostNodeRaceManager.shared,
                                                       domain: legacyNavigationDomain)
            return try await raceCandidates(hosts.map { (.oldResolver, $0) },
                                            lastLiceseId: lastLiceseId, credentials: credentials, clientIP: clientIP)
        }) { return winner }
        try Task<Never, Never>.checkCancellation()

        let cached = await cachedFallbackAddresses()
        let candidates = DNSHostSource.fallbackCandidates(cached: cached,
            builtIn: builtInNavigationDomesticAddresses + builtInNavigationOverseasAddresses)
            .map { ($0.source, DNSResolvedHost(urlString: $0.address, type: "5")) }
        if let winner = try? await OSSRaceDeadline.run(seconds: 6, operation: {
            try await raceCandidates(candidates, lastLiceseId: lastLiceseId,
                                     credentials: credentials, clientIP: clientIP)
        }) { return winner }
        try Task<Never, Never>.checkCancellation()
        return try await OSSRaceDeadline.run(seconds: 6) {
            try await OSSHTTPConfigurationClient.race(lastLiceseId: lastLiceseId)
        }
    }

    @MainActor
    private static func cachedFallbackAddresses() -> [String] {
        guard let cache = try? OSSNavigationStore.shared.load() else { return [] }
        return cache.fallbackEndpoints.domestic + cache.fallbackEndpoints.overseas
    }

    private static func raceCandidates(_ candidates: [(DNSHostSource, DNSResolvedHost)],
                                       lastLiceseId: String, credentials: OSSAuthCredentials,
                                       clientIP: String) async throws -> OSSRaceWinner {
        try await withThrowingTaskGroup(of: OSSRaceWinner?.self) { group in
            var seen = Set<String>()
            for (source, candidate) in candidates.prefix(16) where seen.insert(candidate.urlString).inserted {
                group.addTask {
                    do {
                        let nodes = await DNSHostNormalizer.normalize([candidate])
                        for node in nodes.prefix(8) {
                            try Task<Never, Never>.checkCancellation()
                            do {
                                let request = try OSSAuthRequestBuilder.make(lastLiceseId: lastLiceseId,
                                    signingKeyID: credentials.signingKeyID, signingKeySecret: credentials.signingKeySecret,
                                    clientIP: clientIP)
                                let response = try await OSSAuthTCPClient.request(request, to: node)
                                let navigation = try OSSAuthResponseDecoder.decode(response, lastLiceseId: lastLiceseId)
                                try Task<Never, Never>.checkCancellation()
                                return OSSRaceWinner(source: source, node: node, navigation: navigation)
                            } catch is CancellationError { return nil } catch { }
                        }
                    } catch { }
                    return nil
                }
            }
            defer { group.cancelAll() }
            for try await winner in group { if let winner { return winner } }
            throw OSSNodeRaceError.allSourcesFailed
        }
    }

    private static func raceSource(
        _ source: DNSHostSource,
        lastLiceseId: String,
        credentials: OSSAuthCredentials,
        clientIP: String
    ) async -> OSSRaceWinner? {
        do {
            let hosts = try await resolve(source)
            guard !hosts.isEmpty else { return nil }
            let candidates = await DNSHostNormalizer.normalize(hosts)
            for node in candidates.prefix(8) {
                try Task<Never, Never>.checkCancellation()
                do {
                    let request = try OSSAuthRequestBuilder.make(
                        lastLiceseId: lastLiceseId,
                        signingKeyID: credentials.signingKeyID,
                        signingKeySecret: credentials.signingKeySecret,
                        clientIP: clientIP
                    )
                    let response = try await OSSAuthTCPClient.request(request, to: node)
                    let navigation = try OSSAuthResponseDecoder.decode(response, lastLiceseId: lastLiceseId)
                    try Task<Never, Never>.checkCancellation()
                    return OSSRaceWinner(source: source, node: node, navigation: navigation)
                } catch is CancellationError {
                    return nil
                } catch {
                    // 同一路的候选顺序尝试；单节点失败不影响其他节点或其他 DNS 来源。
                    debugPrint("[OSS竞速] \(source.rawValue) 节点 \(node.urlString) 失败：\(error)")
                }
            }
        } catch is CancellationError {
            return nil
        } catch {
            debugPrint("[OSS竞速] \(source.rawValue) DNS 失败：\(error)")
        }
        return nil
    }

    private static func resolve(_ source: DNSHostSource) async throws -> [DNSResolvedHost] {
        let manager = HostNodeRaceManager.shared
        switch source {
        case .aliAAAA:
            return await AliDNSAsyncBridge.resolve(using: manager)
        case .tencentAAAA:
            return try await manager.tencentDoHAAAA()
        case .cloudflareTXT:
            return try await manager.cloudflareDoHTXT()
        case .cloudflareAAAA:
            return try await manager.cloudflareDoHAAAA()
        case .aliTXT:
            return try await manager.aliDoHTXT()
        case .oldResolver, .cachedFallback, .builtInFallback, .ossHTTPDomestic, .ossHTTPOverseas:
            return []
        }
    }
}

/// 阿里 SDK 的回调不保证到达；桥接时统一做超时和取消收尾，避免拖住任务组。
@MainActor
private final class AliDNSAsyncBridge {
    /// SDK 回调、超时和取消共用同一个 continuation，完成后立即置空。
    private var continuation: CheckedContinuation<[DNSResolvedHost], Never>?
    /// 防止阿里 SDK 不回调时拖住整个竞速。
    private var timeoutTask: Task<Void, Never>?
    /// 处理取消早于 continuation 安装的情况。
    private var cancelled = false

    static func resolve(using manager: HostNodeRaceManager, domain: String? = nil) async -> [DNSResolvedHost] {
        let bridge = AliDNSAsyncBridge()
        // 默认参数在调用方求值，将配置读取留在主线程隔离内。
        let resolvedDomain = domain ?? ali_httpdns_test_domain
        return await withTaskCancellationHandler {
            await bridge.start(using: manager, domain: resolvedDomain)
        } onCancel: {
            Task { @MainActor in bridge.cancel() }
        }
    }

    private func start(using manager: HostNodeRaceManager, domain: String) async -> [DNSResolvedHost] {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            if cancelled {
                finish([])
                return
            }
            timeoutTask = Task { @MainActor in
                try? await Task<Never, Never>.sleep(nanoseconds: 5_000_000_000)
                finish([])
            }
            manager.aliAAATest(domain: domain) { [weak self] hosts in
                Task { @MainActor in self?.finish(hosts) }
            }
        }
    }

    private func cancel() {
        cancelled = true
        finish([])
    }

    private func finish(_ hosts: [DNSResolvedHost]) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(returning: hosts)
    }
}
