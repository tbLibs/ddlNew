//
//  SDKChatRequestWaiter.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// SDK没有请求取消句柄，Swift只结束当前等待并丢弃迟到结果。
@MainActor final class SDKChatRequestWaiter<Value> {
    private var pending: CheckedContinuation<Value, Error>?
    private var finished = false
    private var timeout: Task<Void, Never>?

    /// 使用单次收口和超时，SDK丢回调不会永久占住页面。
    func run(_ start: () -> Void) async throws -> Value {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                guard !finished else { continuation.resume(throwing: CancellationError()); return }
                pending = continuation
                timeout = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: 25_000_000_000) } catch { return }
                    self?.finish(.failure(ChatClientError.unavailable("请求超时，请重试")))
                }
                start()
            }
        } onCancel: { Task { @MainActor in self.cancel() } }
    }

    /// 第一个结果才恢复continuation，重复回调和超时不能再次恢复。
    func finish(_ result: Result<Value, Error>) {
        guard !finished else { return }
        finished = true; timeout?.cancel(); timeout = nil
        let value = pending; pending = nil
        value?.resume(with: result)
    }

    /// 页面关闭同步结束等待，不等待SDK的网络超时。
    func cancel() { finish(.failure(CancellationError())) }
}
