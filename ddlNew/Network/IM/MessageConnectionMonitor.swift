//
//  MessageConnectionMonitor.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//

import Combine
import Foundation
import Network
import UIKit

/// 聚合网络、正式认证和重试状态，不把 ECDH 探测当作用户在线。
@MainActor
final class MessageConnectionMonitor: ObservableObject {
    static let shared = MessageConnectionMonitor()
    @Published private(set) var status: MessageConnectionStatus = .connecting
    private var network: Bool?
    private var foreground = true
    private var visible = false
    private let pathMonitor = NWPathMonitor()
    private var subscriptions: Set<AnyCancellable> = []
    private var probeTask: Task<Void, Never>?

    private init() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            Task { @MainActor in self?.network = available; self?.refresh() }
        }
        pathMonitor.start(queue: DispatchQueue(label: "message.connection.path"))
        let auth = IMUserAuthenticationService.shared
        let recovery = MessageSessionRecovery.shared
        Publishers.MergeMany(auth.objectWillChange.eraseToAnyPublisher(),
                             recovery.objectWillChange.eraseToAnyPublisher(),
                             IMConnectionCoordinator.shared.objectWillChange.eraseToAnyPublisher())
            .sink { [weak self] in
                // objectWillChange 在赋值前发送，合并到下一次主线程执行再读最终状态。
                Task { @MainActor in self?.refresh() }
            }.store(in: &subscriptions)
    }

    func setVisible(_ visible: Bool) {
        self.visible = visible
        refresh()
        if visible { MessageSessionRecovery.shared.ensureRecovery() }
    }

    func setForeground(_ foreground: Bool) {
        self.foreground = foreground
        refresh()
    }

    private func refresh() {
        let recovery = MessageSessionRecovery.shared
        recovery.setAvailable(foreground && network != false)
        let auth = IMUserAuthenticationService.shared
        let failed: Bool
        if recovery.hasPendingIdentity {
            if case .failed = IMConnectionCoordinator.shared.phase { failed = true }
            else { failed = recovery.waitingToRetry }
        } else { failed = auth.connectionEvent == .failed }
        status = .resolve(network: network,
                          authenticated: auth.state == .ready && auth.isAuthenticated,
                          retrying: recovery.isRetrying || auth.state == .reconnecting,
                          failed: failed, localFailure: recovery.failureMessage)
        let eligible = visible && foreground && status == .online
        IMLoggedInReconnectCoordinator.shared.setMessageProbeVisible(eligible)
        if !eligible {
            probeTask?.cancel()
            probeTask = nil
        } else if probeTask == nil {
            probeTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task<Never, Never>.sleep(nanoseconds: 20_000_000_000) }
                    catch { return }
                    guard let self, self.visible, self.foreground, self.status == .online else { return }
                    await IMLoggedInReconnectCoordinator.shared.probeMessageConnection()
                }
            }
        }
    }
}
