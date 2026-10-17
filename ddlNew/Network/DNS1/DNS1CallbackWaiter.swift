//
//  DNS1CallbackWaiter.swift
//  ddlNew
//
//  Created by taobo on 2026/10/17.
//

import Foundation

/// DNS SDK/临时探测没有取消句柄，取消和超时必须立即结束 Swift 等待并忽略迟到回调。
@MainActor final class DNS1CallbackWaiter<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, Error>?
    private var timer: Task<Void, Never>?
    private var cancelled = false

    func run(seconds: Double, start: () -> Void) async throws -> Value {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                guard !cancelled else { finish(.failure(CancellationError())); return }
                timer = Task {
                    do { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
                    catch { return }
                    finish(.failure(DNS1Error.unavailable))
                }
                start()
            }
        } onCancel: {
            Task { @MainActor in self.cancelled = true; self.finish(.failure(CancellationError())) }
        }
    }

    func finish(_ result: Result<Value, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timer?.cancel(); timer = nil
        continuation.resume(with: result)
    }
}
