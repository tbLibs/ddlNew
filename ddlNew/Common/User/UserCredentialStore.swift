//
//  UserCredentialStore.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation
import ObjectMapper
import Security

/// 凭据只写 Keychain；ObjectMapper 负责序列化，避免出现在普通用户资料 JSON 中。
@MainActor
final class UserCredentialStore {
    static let shared = UserCredentialStore()

    private init() {}

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: userCredentialKeychainService,
         kSecAttrAccount as String: userCredentialKeychainAccount]
    }

    func load() throws -> UserSessionCredentials? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw UserSessionError.keychainFailure(status) }
        guard let data = result as? Data, let json = String(data: data, encoding: .utf8),
              let record = Mapper<UserSessionCredentials>().map(JSONString: json), record.isValid else {
            throw UserSessionError.invalidData
        }
        return record
    }

    func save(_ credentials: UserSessionCredentials) throws {
        guard credentials.isValid, let json = Mapper<UserSessionCredentials>().toJSONString(credentials),
              let data = json.data(using: .utf8) else { throw UserSessionError.invalidData }
        let values: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        // 原地更新；不先删除，避免写入失败把上一份凭据也丢掉。
        var status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw UserSessionError.keychainFailure(status) }
    }

    func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw UserSessionError.keychainFailure(status)
        }
    }
}
