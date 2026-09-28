//
//  IMHandshakeWaiter.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

/// 回调、通知、超时、取消共享一次性完成入口；迟到回调不能重复恢复 continuation。
@MainActor
final class IMHandshakeWaiter {
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
            Task { @MainActor [weak self] in
                guard success() else { return }
                self?.finish(.success(true))
            }
        })
        observers.append(center.addObserver(forName: Notification.Name("socketECDHDidConnectFailure"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.finish(.failure(IMConnectionError.handshakeFailed)) }
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
