//
//  OSSNodeRaceCoordinator.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation

struct OSSAuthCredentials: Sendable {
    let signingKeyID: String
    let signingKeySecret: String
}

struct OSSRaceWinner: Sendable {
    let source: DNSHostSource
    let node: DNSResolvedHost
    let navigation: OSSNavigationResult
}

enum OSSNodeRaceError: Error {
    case missingAppID
    case missingCredentials
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
    private var continuation: CheckedContinuation<[DNSResolvedHost], Never>?
    private var timeoutTask: Task<Void, Never>?
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
