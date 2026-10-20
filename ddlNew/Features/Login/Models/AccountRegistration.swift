import Foundation

/// 对应旧项目账号注册；手机号和邮箱注册由独立流程处理。
nonisolated struct AccountRegistrationContext: Equatable {
    let connectionID: UUID
    let registerMethod: String
    let requiresInviteCode: Bool
    let requiresPasswordSymbol: Bool

    var allowsAccountRegistration: Bool {
        // 老项目未知配置默认提供账号注册，已知组合遵循系统设置。
        !["2", "3", "4"].contains(registerMethod)
    }
}

nonisolated struct AccountRegistrationInput {
    let account: String
    let password: String
    let confirmation: String
    let inviteCode: String

    func validate(in context: AccountRegistrationContext) throws {
        guard context.allowsAccountRegistration else { throw AccountRegistrationError.disabled }
        guard account.range(of: "^[A-Za-z]{2}[A-Za-z0-9]{4,14}$", options: .regularExpression) != nil else {
            throw AccountRegistrationError.invalidAccount
        }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*-+=/\\?;:,.~`_\"'")
        let letters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        let numbers = CharacterSet(charactersIn: "0123456789")
        let scalars = password.unicodeScalars
        guard (6...16).contains(password.utf16.count), scalars.allSatisfy({ allowed.contains($0) }),
              scalars.contains(where: { letters.contains($0) }), scalars.contains(where: { numbers.contains($0) }),
              !context.requiresPasswordSymbol || scalars.contains(where: { !letters.contains($0) && !numbers.contains($0) }) else {
            throw AccountRegistrationError.invalidPassword(requiresSymbol: context.requiresPasswordSymbol)
        }
        guard password == confirmation else { throw AccountRegistrationError.passwordMismatch }
        guard !context.requiresInviteCode || !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AccountRegistrationError.inviteCodeRequired
        }
    }
}

nonisolated enum AccountRegistrationError: LocalizedError {
    case disabled, invalidAccount, passwordMismatch, inviteCodeRequired, accountExists
    case invalidPassword(requiresSymbol: Bool)

    var errorDescription: String? {
        switch self {
        case .disabled: return "当前俱乐部未开启账号注册"
        case .invalidAccount: return "账号长度6～16位，前两位必须为英文，只支持英文或数字"
        case .invalidPassword(let symbol): return symbol ? "密码长度6～16位，须包含字母、数字和英文符号" : "密码长度6～16位，须包含字母、数字，可使用英文符号"
        case .passwordMismatch: return "两次输入的密码不一致"
        case .inviteCodeRequired: return "请输入邀请码"
        case .accountExists: return "账号已存在，请使用账号密码登录"
        }
    }
}
