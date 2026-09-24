//
//  SystemConfigCrypto.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation

/// 业务请求验签或系统配置解密失败；模拟器没有老项目静态库对应的架构。
enum SystemConfigCryptoError: Error {
    case unavailableOnSimulator
    case signatureFailed
    case invalidPayload
    case decryptionFailed
}

/// 只复用独立的 LXChatEncrypt 工具库，不引入 IM SDK 或其 TCP 客户端。
enum SystemConfigCrypto {
    static func signature(timestamp: Int64) throws -> String {
        try signedValue(
            method: "getSystemConfig",
            uri: "system/v2/getSystemConfig",
            timestamp: timestamp
        )
    }

    /// 老项目普通 auth 接口使用 tenantCode 和去掉 /auth/ 的 URI 验签。
    static func authenticationSignature(tenantCode: String, timestamp: Int64) throws -> String {
        try signedValue(
            method: tenantCode,
            uri: NetworkPath.generateEncryptKeySignatureURI,
            timestamp: timestamp
        )
    }

    private static func signedValue(method: String, uri: String, timestamp: Int64) throws -> String {
        #if targetEnvironment(simulator)
        throw SystemConfigCryptoError.unavailableOnSimulator
        #else
        guard let value = LXChatEncrypt.method5(
            method,
            uri: uri,
            timestamp: timestamp
        ), !value.isEmpty else {
            throw SystemConfigCryptoError.signatureFailed
        }
        return value
        #endif
    }

    /// 老项目先接受明文 JSON；非 JSON 字符串才调用 method6 解密。
    static func configurationDictionary(from payload: Any) throws -> [String: Any] {
        if let dictionary = payload as? [String: Any] {
            return dictionary
        }
        guard let encrypted = payload as? String, !encrypted.isEmpty else {
            throw SystemConfigCryptoError.invalidPayload
        }
        if let dictionary = jsonDictionary(from: encrypted) {
            return dictionary
        }

        #if targetEnvironment(simulator)
        throw SystemConfigCryptoError.unavailableOnSimulator
        #else
        guard let plaintext = LXChatEncrypt.method6(encrypted),
              let dictionary = jsonDictionary(from: plaintext) else {
            throw SystemConfigCryptoError.decryptionFailed
        }
        return dictionary
        #endif
    }

    private static func jsonDictionary(from text: String) -> [String: Any]? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) else {
            return nil
        }
        return object as? [String: Any]
    }
}
