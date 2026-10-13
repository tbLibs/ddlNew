//
//  PasswordSecurityStatus.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

nonisolated struct PasswordSecurityStatus: Sendable {
    let isWeakPassword: Bool
    let type: String
    let forcedPasswordReset: Bool

    init(isWeakPassword: Bool, type: String, forcedPasswordReset: Bool) {
        self.isWeakPassword = isWeakPassword
        self.type = type
        self.forcedPasswordReset = forcedPasswordReset
    }

    init(json: [String: Any]) throws {
        guard let weak = Self.bool(json["isWeakPassword"]) else { throw AccountLoginError.invalidResponse }
        isWeakPassword = weak
        type = json["type"] as? String ?? ""
        let role = json["roleConfigMap"] as? [String: Any]
        if let value = role?["forced_password_reset"] {
            guard let forced = Self.bool(value) else { throw AccountLoginError.invalidResponse }
            forcedPasswordReset = forced
        } else { forcedPasswordReset = false }
    }

    func requiresChange(hasSubmittedPassword: Bool) -> Bool {
        isWeakPassword && (forcedPasswordReset || hasSubmittedPassword)
    }

    var message: String {
        type == "PASSWORD_EQ_ACCOUNT" ? "密码与账号相同，请修改密码以保护账号安全" : "当前密码强度不足，请修改密码以保护账号安全"
    }

    private static func bool(_ value: Any?) -> Bool? {
        if let number = value as? NSNumber, number == 0 || number == 1 { return number.boolValue }
        guard let string = value as? String else { return nil }
        switch string.lowercased() {
        case "1", "true": return true
        case "0", "false": return false
        default: return nil
        }
    }
}

nonisolated struct PasswordSecurityRequest: Identifiable, Equatable {
    let id: UUID
    let isForced: Bool
    let message: String
}
