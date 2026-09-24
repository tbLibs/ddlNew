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

/// 竞速首胜结果，保留 DNS 来源、OSS 地址和解密后的导航数据。
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
    case missingAppID
    /// 签名常量缺失。
    case missingCredentials
    /// 五路 DNS 及其候选节点均未得到有效导航响应。
    case allSourcesFailed
}

/// 五路 DNS 同时开始；每一路按候选顺序尝试 OSS TCP，首个通过导航校验的节点获胜。
enum OSSNodeRaceCoordinator {
    static func race(
        appID: String,
        credentials: OSSAuthCredentials,
        clientIP: String = ""
    ) async throws -> OSSRaceWinner {
        guard !appID.isEmpty else { throw OSSNodeRaceError.missingAppID }
        guard !credentials.signingKeyID.isEmpty, !credentials.signingKeySecret.isEmpty else {
            throw OSSNodeRaceError.missingCredentials
        }

        return try await withThrowingTaskGroup(of: OSSRaceWinner?.self) { group in
            for source in DNSHostSource.allCases {
                group.addTask {
                    await raceSource(
                        source,
                        appID: appID,
                        credentials: credentials,
                        clientIP: clientIP
                    )
                }
            }

            for try await outcome in group {
                if let winner = outcome {
                    // 子任务取消会中止 Rx 请求和 TCP 连接；已进入回调的阿里 SDK 结果会被忽略。
                    group.cancelAll()
                    return winner
                }
            }
            throw OSSNodeRaceError.allSourcesFailed
        }
    }

    private static func raceSource(
        _ source: DNSHostSource,
        appID: String,
        credentials: OSSAuthCredentials,
        clientIP: String
    ) async -> OSSRaceWinner? {
        do {
            let hosts = try await resolve(source)
            guard !hosts.isEmpty else { return nil }
            let candidates = await DNSHostNormalizer.normalize(hosts)
            for node in candidates {
                try Task<Never, Never>.checkCancellation()
                do {
                    let request = try OSSAuthRequestBuilder.make(
                        appID: appID,
                        signingKeyID: credentials.signingKeyID,
                        signingKeySecret: credentials.signingKeySecret,
                        clientIP: clientIP
                    )
                    let response = try await OSSAuthTCPClient.request(request, to: node)
                    let navigation = try OSSAuthResponseDecoder.decode(response, appID: appID)
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

    static func resolve(using manager: HostNodeRaceManager) async -> [DNSResolvedHost] {
        let bridge = AliDNSAsyncBridge()
        return await withTaskCancellationHandler {
            await bridge.start(using: manager)
        } onCancel: {
            Task { @MainActor in bridge.cancel() }
        }
    }

    private func start(using manager: HostNodeRaceManager) async -> [DNSResolvedHost] {
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
            manager.aliAAATest { [weak self] hosts in
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
