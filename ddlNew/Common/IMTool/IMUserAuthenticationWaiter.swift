//
//  IMUserAuthenticationWaiter.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

/// AUTH 的一次性等待；成功、拒绝、取消和超时只能恢复 continuation 一次。
@MainActor
final class IMUserAuthenticationWaiter {
    private var continuation: CheckedContinuation<Void, Error>?
    private var finished = false
    private var timeoutTask: Task<Void, Never>?

    func run(timeoutNanoseconds: UInt64 = 30_000_000_000,
             start: @MainActor () -> Void) async throws {
        try await withTaskCancellationHandler {
            try Task<Never, Never>.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !finished else { continuation.resume(throwing: CancellationError()); return }
                self.continuation = continuation
                timeoutTask = Task { [weak self] in
                    do {
                        try await Task<Never, Never>.sleep(nanoseconds: timeoutNanoseconds)
                        self?.finish(.failure(UserSessionError.authenticationTimedOut))
                    } catch { /* 正常结束会取消计时任务。 */ }
                }
                start()
            }
        } onCancel: {
            Task { @MainActor in self.finish(.failure(CancellationError())) }
        }
    }

    func finish(_ result: Result<Void, Error>) {
        guard !finished else { return }
        finished = true
        timeoutTask?.cancel()
        timeoutTask = nil
        let pending = continuation
        continuation = nil
        pending?.resume(with: result)
    }
}
