//
//  MessageSessionRecovery.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//

import Foundation
import Combine

nonisolated struct MessageRecoveryIdentity: Equatable, Sendable {
    let id = UUID()
    let userUID: String
    let license: String
}

nonisolated enum MessageRecoveryFailure: Error {
    case retryable
    case invalidIdentity
    case local(String)
}

/// 页面只触发恢复；任务归会话所有，切 Tab 和进入聊天不会取消它。
@MainActor
final class MessageSessionRecovery: ObservableObject {
    @Published private(set) var identity: MessageRecoveryIdentity?
    @Published private(set) var failureMessage: String?
    @Published private(set) var isRetrying = false
    @Published private(set) var waitingToRetry = false
    var hasPendingIdentity: Bool { identity != nil }

    private let loadLocalSnapshot: @MainActor (MessageRecoveryIdentity) async -> Void
    private var localSnapshotRequested = false
    private let attempt: @MainActor (MessageRecoveryIdentity) async throws -> Void
    private let invalidate: @MainActor (MessageRecoveryIdentity) -> Void
    private let retryDelay: TimeInterval
    private var task: Task<Void, Never>?
    private var available = true

    init(retryDelay: TimeInterval = 1,
         loadLocalSnapshot: @escaping @MainActor (MessageRecoveryIdentity) async -> Void = { _ in },
         attempt: @escaping @MainActor (MessageRecoveryIdentity) async throws -> Void,
         invalidate: @escaping @MainActor (MessageRecoveryIdentity) -> Void) {
        self.loadLocalSnapshot = loadLocalSnapshot
        self.retryDelay = retryDelay
        self.attempt = attempt
        self.invalidate = invalidate
    }

    func prepare(userUID: String, license: String) {
        cancel()
        identity = MessageRecoveryIdentity(userUID: userUID, license: license)
        localSnapshotRequested = true
    }

    func setAvailable(_ available: Bool) { self.available = available }

    func cancel() {
        identity = nil
        localSnapshotRequested = false
        task?.cancel()
        task = nil
        failureMessage = nil
        isRetrying = false
        waitingToRetry = false
    }

    func retryLocalSnapshot() {
        localSnapshotRequested = true
        retry()
    }

    func retry() {
        failureMessage = nil
        ensureRecovery()
    }

    func ensureRecovery() {
        guard task == nil, failureMessage == nil, let identity else { return }
        task = Task { [weak self] in
            guard let self else { return }
            defer { if self.identity == identity { self.task = nil } }
            var failures = 0
            while self.identity == identity, !Task.isCancelled {
                do {
                    try await self.waitUntilAvailable(identity)
                    self.waitingToRetry = false
                    try await self.attempt(identity)
                    guard self.identity == identity, !Task.isCancelled else { return }
                    self.cancel()
                    return
                } catch {
                    guard self.identity == identity, !Task.isCancelled else { return }
                    switch error {
                    case MessageRecoveryFailure.invalidIdentity:
                        self.cancel()
                        self.invalidate(identity)
                        return
                    case MessageRecoveryFailure.local(let message):
                        self.failureMessage = message
                        return
                    default:
                        self.isRetrying = true
                        self.waitingToRetry = true
                        // 只累计前台有网时间；离线或后台不会烧掉退避时间。
                        var remaining = self.retryDelay * Double(1 << min(failures, 4))
                        failures += 1
                        while remaining > 0 {
                            do {
                                try await self.waitUntilAvailable(identity)
                                let step = min(remaining, 0.1)
                                try await Task<Never, Never>.sleep(nanoseconds: UInt64(step * 1_000_000_000))
                                if self.available { remaining -= step }
                            } catch { return }
                        }
                    }
                }
            }
        }
    }

    private func waitUntilAvailable(_ identity: MessageRecoveryIdentity) async throws {
        while true {
            try Task<Never, Never>.checkCancellation()
            guard self.identity == identity else { throw CancellationError() }
            // 本地读取不等网络；重试也在会话任务内串行执行，不与 AUTH 抢占 SDK 数据库。
            if localSnapshotRequested {
                localSnapshotRequested = false
                await loadLocalSnapshot(identity)
                try Task<Never, Never>.checkCancellation()
                guard self.identity == identity else { throw CancellationError() }
            }
            if available { return }
            try await Task<Never, Never>.sleep(nanoseconds: 50_000_000)
        }
    }
}
