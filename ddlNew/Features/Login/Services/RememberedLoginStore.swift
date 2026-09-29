//
//  RememberedLoginStore.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation
import ObjectMapper
import Security

/// 只负责记住密码的 Keychain 读写，不处理登录请求、token 或自动登录。
@MainActor
final class RememberedLoginStore {
    static let shared = RememberedLoginStore()

    private init() {}

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: rememberedLoginKeychainService,
         kSecAttrAccount as String: rememberedLoginKeychainAccount]
    }

    func load(lastLiceseId: String) throws -> RememberedLoginCredentials? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw UserSessionError.keychainFailure(status) }
        guard let data = result as? Data, let json = String(data: data, encoding: .utf8),
              let record = Mapper<RememberedLoginCredentials>().map(JSONString: json), record.isValid else {
            throw UserSessionError.invalidData
        }
        return record.lastLiceseId == lastLiceseId ? record : nil
    }

    func save(_ record: RememberedLoginCredentials) throws {
        guard record.isValid, let json = Mapper<RememberedLoginCredentials>().toJSONString(record),
              let data = json.data(using: .utf8) else { throw UserSessionError.invalidData }
        let values: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        // 原地更新，不先删除；密码不会经 iCloud 同步或迁移到其他设备。
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
