//
//  SessionMaintenanceEngine.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 前台串行刷新；取消后即使底层 SDK 回调到达，也不能提交旧会话结果。
@MainActor
final class SessionMaintenanceEngine {
    typealias Operation = @MainActor (@escaping @MainActor () -> Bool) async -> Void
    private let operation: Operation
    private let interval: @MainActor () -> UInt64
    private var identity: String?
    private var requiresAuthentication = false
    private var foreground = true
    private var authenticated = false
    private var generation = UUID()
    private var task: Task<Void, Never>?
    private var pendingRefresh = false
    private var refreshing = false

    init(interval: @escaping @MainActor () -> UInt64 = {
        UInt64(Int.random(in: 180...480)) * 1_000_000_000
    }, operation: @escaping Operation) {
        self.interval = interval
        self.operation = operation
    }

    func start(identity: String, requiresAuthentication: Bool) {
        stop()
        self.identity = identity
        self.requiresAuthentication = requiresAuthentication
        refreshNow()
    }

    func stop() {
        generation = UUID()
        task?.cancel()
        task = nil
        pendingRefresh = false
        refreshing = false
        identity = nil
    }

    func setForegroundActive(_ active: Bool) {
        guard foreground != active else { return }
        foreground = active
        restart()
    }

    func setAuthenticated(_ value: Bool) {
        guard authenticated != value else { return }
        authenticated = value
        if requiresAuthentication { restart() }
    }

    private var canRun: Bool {
        identity != nil && foreground && (!requiresAuthentication || authenticated)
    }

    private func restart() {
        generation = UUID()
        task?.cancel()
        task = nil
        pendingRefresh = false
        refreshing = false
        refreshNow()
    }

    func refreshNow() {
        guard canRun else { return }
        // 多个前台/节点切换通知合并成下一轮，避免重叠请求。
        if refreshing { pendingRefresh = true; return }
        // 等待周期时收到主动刷新，立即取消等待；正在请求则合并下一轮。
        if task != nil {
            generation = UUID()
            task?.cancel()
            task = nil
        }
        let run = generation
        task = Task { [weak self] in
            guard let self else { return }
            let current: @MainActor () -> Bool = { [weak self] in
                guard let self else { return false }
                return self.generation == run && self.canRun && !Task.isCancelled
            }
            while current() {
                self.pendingRefresh = false
                self.refreshing = true
                await self.operation(current)
                guard current() else { return }
                self.refreshing = false
                if self.pendingRefresh { continue }
                do { try await Task<Never, Never>.sleep(nanoseconds: self.interval()) }
                catch { return }
            }
        }
    }
}
