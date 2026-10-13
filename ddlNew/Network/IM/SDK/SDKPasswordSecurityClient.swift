//
//  SDKPasswordSecurityClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore

/// 复用旧 SDK 的验签、解密和 HTTP/TCP 通道；修改本人密码走 user 接口。
@MainActor
final class SDKPasswordSecurityClient: PasswordSecurityDriving {
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }

    func fetchEncryptKey() async throws -> String {
        let waiter = SDKLoginRequestWaiter<String>()
        return try await waiter.run {
            sdk.authGetEncryptKeySuccess({ data, _ in
                let result: Result<String, AccountLoginError>
                if let key = data as? String, !key.isEmpty { result = .success(key) }
                else { result = .failure(.invalidEncryptKey) }
                Task { @MainActor in waiter.finish(result) }
            }, onFailure: { code, _, _ in
                Task { @MainActor in waiter.finish(.failure(.businessFailure(code: code, message: "获取密码加密密钥失败，请重试"))) }
            })
        }
    }

    func checkStrength(parameters: [String: Any]) async throws -> PasswordSecurityStatus {
        let waiter = SDKLoginRequestWaiter<PasswordSecurityStatus>()
        return try await waiter.run {
            sdk.authCheckPasswordStrength(with: NSMutableDictionary(dictionary: parameters), onSuccess: { data, _ in
                let result: Result<PasswordSecurityStatus, AccountLoginError>
                if let json = data as? [String: Any], let status = try? PasswordSecurityStatus(json: json) { result = .success(status) }
                else { result = .failure(.invalidResponse) }
                Task { @MainActor in waiter.finish(result) }
            }, onFailure: { code, _, _ in
                Task { @MainActor in waiter.finish(.failure(.businessFailure(code: code, message: "密码安全检查暂未完成，请稍后重试"))) }
            })
        }
    }

    func checkOldPassword(parameters: [String: Any]) async throws -> Bool {
        let waiter = SDKLoginRequestWaiter<Bool>()
        return try await waiter.run {
            sdk.userCheckUserPassword(with: NSMutableDictionary(dictionary: parameters), onSuccess: { data, _ in
                let result = Self.booleanResult(data)
                Task { @MainActor in waiter.finish(result) }
            }, onFailure: { code, _, _ in
                Task { @MainActor in waiter.finish(.failure(.businessFailure(code: code, message: "原密码验证失败，请重试"))) }
            })
        }
    }

    func resetPassword(parameters: [String: Any]) async throws -> Bool {
        let waiter = SDKLoginRequestWaiter<Bool>()
        return try await waiter.run {
            sdk.userResetPassword(with: NSMutableDictionary(dictionary: parameters), onSuccess: { data, _ in
                let result = Self.booleanResult(data)
                Task { @MainActor in waiter.finish(result) }
            }, onFailure: { code, _, _ in
                Task { @MainActor in waiter.finish(.failure(.businessFailure(code: code, message: "修改密码未完成，请重试"))) }
            })
        }
    }

    nonisolated private static func booleanResult(_ data: Any?) -> Result<Bool, AccountLoginError> {
        if let number = data as? NSNumber, number == 0 || number == 1 { return .success(number.boolValue) }
        if let string = data as? String {
            switch string.lowercased() {
            case "true", "1": return .success(true)
            case "false", "0": return .success(false)
            default: break
            }
        }
        return .failure(.invalidResponse)
    }
}
