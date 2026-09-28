//
//  SDKLoginRequestWaiter.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

/// SDK 未提供取消句柄；取消结束 Swift 等待，迟到回调不能覆盖新页面状态。
@MainActor
final class SDKLoginRequestWaiter<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, Error>?
    /// 只保存是否结束，不长期持有密钥或登录成功凭据。
    private var finished = false
    private var timeoutTask: Task<Void, Never>?
    private let timeoutNanoseconds: UInt64

    init(timeoutNanoseconds: UInt64 = 20_000_000_000) {
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    func run(start: @MainActor () -> Void) async throws -> Value {
        try await withTaskCancellationHandler {
            try Task<Never, Never>.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                guard !finished else { continuation.resume(throwing: CancellationError()); return }
                self.continuation = continuation
                timeoutTask = Task { [weak self] in
                    guard let self else { return }
                    do {
                        try await Task<Never, Never>.sleep(nanoseconds: self.timeoutNanoseconds)
                        self.finish(.failure(.timedOut))
                    } catch { /* 正常完成会取消计时，不再次返回失败。 */ }
                }
                start()
            }
        } onCancel: {
            Task { @MainActor in self.cancel() }
        }
    }

    func finish(_ result: Result<Value, AccountLoginError>) {
        guard !finished else { return }
        finished = true
        timeoutTask?.cancel()
        timeoutTask = nil
        let pending = continuation
        continuation = nil
        switch result {
        case .success(let value): pending?.resume(returning: value)
        case .failure(let error): pending?.resume(throwing: error)
        }
    }

    private func cancel() {
        guard !finished else { return }
        finished = true
        timeoutTask?.cancel()
        timeoutTask = nil
        let pending = continuation
        continuation = nil
        pending?.resume(throwing: CancellationError())
    }
}
