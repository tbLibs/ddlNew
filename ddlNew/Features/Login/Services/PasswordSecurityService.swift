//
//  PasswordSecurityService.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

@MainActor
protocol PasswordSecurityDriving {
    func fetchEncryptKey() async throws -> String
    func checkStrength(parameters: [String: Any]) async throws -> PasswordSecurityStatus
    func checkOldPassword(parameters: [String: Any]) async throws -> Bool
    func resetPassword(parameters: [String: Any]) async throws -> Bool
}

/// 仅在领取密钥期间短暂持有明文；消费、取消和后台都会立即释放引用，不新增持久化。
@MainActor
final class PasswordSecuritySecret {
    private var value: String?
    var isEmpty: Bool { value == nil }
    init(_ value: String) { self.value = value }
    func take() -> String? { defer { value = nil }; return value }
    func discard() { value = nil }
}

@MainActor
final class PasswordSecurityService {
    static let shared = PasswordSecurityService(driver: SDKPasswordSecurityClient(), encrypt: { value in
        #if targetEnvironment(simulator)
        throw AccountLoginError.unavailableOnSimulator
        #else
        guard let encrypted = LXChatEncrypt.method4(value), !encrypted.isEmpty else { throw AccountLoginError.encryptionFailed }
        return encrypted
        #endif
    })
    private let driver: any PasswordSecurityDriving
    private let encrypt: @MainActor (String) throws -> String

    init(driver: any PasswordSecurityDriving, encrypt: @escaping @MainActor (String) throws -> String) {
        self.driver = driver
        self.encrypt = encrypt
    }

    func check(userUID: String, password: PasswordSecuritySecret?, valid: @MainActor () -> Bool) async throws -> PasswordSecurityStatus {
        defer { password?.discard() }
        try ensureCurrent(valid)
        let key = try await driver.fetchEncryptKey()
        try ensureCurrent(valid)
        guard !key.isEmpty else { throw AccountLoginError.invalidEncryptKey }
        var parameters: [String: Any] = ["userUid": userUID]
        if let plain = password?.take() {
            guard !plain.isEmpty else { throw AccountLoginError.emptyPassword }
            parameters["password"] = try encrypted(key + plain)
            parameters["encryptKey"] = key
        }
        let result = try await driver.checkStrength(parameters: parameters)
        try ensureCurrent(valid)
        return result
    }

    func verifyOldPassword(userUID: String, password: PasswordSecuritySecret, valid: @MainActor () -> Bool) async throws {
        let parameters = try await parameters(userUID: userUID, password: password, valid: valid)
        let success = try await driver.checkOldPassword(parameters: parameters)
        try ensureCurrent(valid)
        guard success else { throw PasswordSecurityError.oldPasswordRejected }
    }

    func changePassword(userUID: String, password: PasswordSecuritySecret, valid: @MainActor () -> Bool,
                        onResetSucceeded: @MainActor () -> Void = {}) async throws {
        let parameters = try await parameters(userUID: userUID, password: password, valid: valid)
        let success = try await driver.resetPassword(parameters: parameters)
        // 已提交的修改无法撤销；即使此刻转后台，也先保留真实成功结果供返回前台后退出。
        if success { onResetSucceeded() }
        try ensureCurrent(valid)
        guard success else { throw PasswordSecurityError.resetRejected }
    }

    private func parameters(userUID: String, password: PasswordSecuritySecret, valid: @MainActor () -> Bool) async throws -> [String: Any] {
        defer { password.discard() }
        try ensureCurrent(valid)
        let key = try await driver.fetchEncryptKey()
        try ensureCurrent(valid)
        guard !key.isEmpty else { throw AccountLoginError.invalidEncryptKey }
        guard let plain = password.take(), !plain.isEmpty else { throw AccountLoginError.emptyPassword }
        return ["userUid": userUID, "password": try encrypted(key + plain), "encryptKey": key]
    }

    private func encrypted(_ value: String) throws -> String {
        let cipher = try encrypt(value)
        guard !cipher.isEmpty else { throw AccountLoginError.encryptionFailed }
        return cipher
    }

    private func ensureCurrent(_ valid: @MainActor () -> Bool) throws {
        try Task<Never, Never>.checkCancellation()
        guard valid() else { throw AccountLoginError.connectionChanged }
    }
}
