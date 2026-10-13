//
//  PasswordChangeInput.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

nonisolated enum PasswordChangeInput {
    static func validate(password: String, confirmation: String, requiresSymbol: Bool) throws {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*-+=/\\?;:,.~`_\"'")
        let letters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        let digits = CharacterSet(charactersIn: "0123456789")
        let scalars = password.unicodeScalars
        guard (6...16).contains(password.utf16.count), scalars.allSatisfy({ allowed.contains($0) }),
              scalars.contains(where: { letters.contains($0) }), scalars.contains(where: { digits.contains($0) }),
              !requiresSymbol || scalars.contains(where: { !letters.contains($0) && !digits.contains($0) }) else {
            throw PasswordSecurityError.invalidPassword(requiresSymbol: requiresSymbol)
        }
        guard password == confirmation else { throw PasswordSecurityError.passwordMismatch }
    }
}

nonisolated enum PasswordSecurityError: LocalizedError {
    case oldPasswordRejected, resetRejected, passwordMismatch
    case invalidPassword(requiresSymbol: Bool)
    var errorDescription: String? {
        switch self {
        case .oldPasswordRejected: return "原密码不正确，请重新输入"
        case .resetRejected: return "修改密码失败，请重试"
        case .passwordMismatch: return "两次输入的密码不一致"
        case .invalidPassword(let symbol):
            return symbol ? "密码长度6～16位，须包含字母、数字和英文符号" : "密码长度6～16位，须包含字母和数字，可使用英文符号"
        }
    }
}
