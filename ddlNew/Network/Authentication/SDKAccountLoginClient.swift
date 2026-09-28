//
//  SDKAccountLoginClient.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation
import NoaChatCore
import ObjectMapper

/// 使用 SDK 现有验签、解密和 HTTP 转 TCP 通道，不另写一套登录协议。
@MainActor
final class SDKAccountLoginClient: AccountLoginSDKDriving {
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }

    func fetchEncryptKey() async throws -> String {
        let waiter = SDKLoginRequestWaiter<String>()
        return try await waiter.run {
            self.sdk.authGetEncryptKeySuccess({ data, _ in
                let result: Result<String, AccountLoginError>
                if let key = data as? String, !key.isEmpty {
                    result = .success(key)
                } else {
                    result = .failure(.invalidEncryptKey)
                }
                Task { @MainActor in waiter.finish(result) }
            }, onFailure: { code, message, _ in
                let error = AccountLoginError.businessFailure(code: code, message: message ?? "")
                Task { @MainActor in waiter.finish(.failure(error)) }
            })
        }
    }

    func submit(parameters: [String: Any], captchaChannel: Int) async throws -> AccountLoginResponse {
        let waiter = SDKLoginRequestWaiter<AccountLoginResponse>()
        return try await waiter.run {
            self.sdk.configSDKCaptchaChannel(captchaChannel)
            // 尚未接设备凭证缓存；清掉残留，避免跨账号误用设备凭证。
            self.sdk.configSDKDeviceSecret(nil)
            self.sdk.authUserLogin(with: NSMutableDictionary(dictionary: parameters), onSuccess: { data, _ in
                let result: Result<AccountLoginResponse, AccountLoginError>
                // 回调返回的是解密后的 data，不是带 code/data 的外层响应。
                if let json = data as? [String: Any],
                   let response = Mapper<AccountLoginResponse>().map(JSON: json), response.isValid {
                    result = .success(response)
                } else {
                    result = .failure(.invalidResponse)
                }
                Task { @MainActor in waiter.finish(result) }
            }, onFailure: { code, message, _ in
                let error = AccountLoginError.businessFailure(code: code, message: message ?? "")
                Task { @MainActor in waiter.finish(.failure(error)) }
            })
        }
    }
}

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
