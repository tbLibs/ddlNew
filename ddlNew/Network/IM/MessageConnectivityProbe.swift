//
//  MessageConnectivityProbe.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//

import Foundation

/// 无取消句柄的临时探测通过轮次与所有权检查隔离迟到结果。
@MainActor
final class MessageConnectivityProbe {
    private var generation = UUID()
    private var probing = false
    func cancel() { generation = UUID(); probing = false }

    func run(isCurrent: @escaping @MainActor () -> Bool,
             probe: @MainActor () async throws -> Bool,
             reconnect: @MainActor () -> Void) async {
        guard !probing, isCurrent(), !Task.isCancelled else { return }
        let run = generation
        probing = true
        defer { if generation == run { probing = false } }
        let succeeded: Bool
        do { succeeded = try await probe() }
        catch is CancellationError { return }
        catch { succeeded = false }
        guard generation == run, !Task.isCancelled, isCurrent(), !succeeded else { return }
        reconnect()
    }
}
