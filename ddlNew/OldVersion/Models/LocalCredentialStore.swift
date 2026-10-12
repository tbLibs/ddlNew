import Foundation
import Security

struct LocalCredentials: Codable {
    let account: String
    let password: String
}

/// Keeps the demo account password in this device's Keychain, outside the club snapshot.
struct LocalCredentialStore {
    private var service: String {
        let base = "com.ddlNew.club.localAccount"
        #if DEBUG
        if let id = ProcessInfo.processInfo.environment["CLUB_UI_TEST_DATABASE_ID"], UUID(uuidString: id) != nil {
            return "\(base).\(id)"
        }
        #endif
        return base
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "member"]
    }

    func load() throws -> LocalCredentials? {
        var result: CFTypeRef?
        var attributes = query
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw LocalCredentialError.keychain(status) }
        guard let data = result as? Data else { throw LocalCredentialError.invalidData }
        return try JSONDecoder().decode(LocalCredentials.self, from: data)
    }

    func save(_ credentials: LocalCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw LocalCredentialError.keychain(addStatus) }
        } else if status != errSecSuccess {
            throw LocalCredentialError.keychain(status)
        }
    }

    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw LocalCredentialError.keychain(status)
        }
    }
}

enum LocalCredentialError: Error {
    case keychain(OSStatus)
    case invalidData
}
