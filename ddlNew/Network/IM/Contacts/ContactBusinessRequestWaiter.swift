//
//  ContactBusinessRequestWaiter.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// SDK没有取消句柄；只结束本层等待，已提交业务仍须回读确认。
@MainActor final class ContactBusinessRequestWaiter<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, Error>?
    private var finished = false
    private var timer: Task<Void, Never>?

    /// 有界等待避免缺失回调将页面永远锁在提交状态。
    func run(start: @MainActor () -> Void) async throws -> Value {
        try await withTaskCancellationHandler {
            try Task<Never, Never>.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                guard !finished else { continuation.resume(throwing: CancellationError()); return }
                self.continuation = continuation
                timer = Task {
                    do { try await Task.sleep(nanoseconds: 20_000_000_000); finish(.failure(ContactBusinessError.invalidInput("请求超时，请刷新状态后重试"))) }
                    catch { /* 请求已结束时取消计时。 */ }
                }
                start()
            }
        } onCancel: { Task { @MainActor in self.cancel() } }
    }

    /// 多次SDK回调只消费第一次回执，释放continuation及计时任务。
    func finish(_ result: Result<Value, Error>) {
        guard !finished else { return }; finished = true; timer?.cancel(); timer = nil
        let pending = continuation; continuation = nil; pending?.resume(with: result)
    }

    /// 退出时取消Swift等待，不声称撤销服务端已收到的业务操作。
    func cancel() { finish(.failure(CancellationError())) }
}
