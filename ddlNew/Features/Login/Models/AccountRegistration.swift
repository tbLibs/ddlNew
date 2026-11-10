import Foundation

/// 账号、手机号共用密码规则，手机号另外要求6位验证码。
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

    var kind: AccountIdentity.Kind = .account
    var areaCode = "86"
    var code = ""
    var identity: AccountIdentity { AccountIdentity(kind: kind, value: account, areaCode: areaCode) }

    func validate(in context: AccountRegistrationContext) throws {
        guard kind == .account ? context.allowsAccountRegistration : kind.allowed(by: context.registerMethod) else { throw AccountRegistrationError.disabled }
        try identity.validate()
        if kind == .account {
        guard account.range(of: "^[A-Za-z]{2}[A-Za-z0-9]{4,14}$", options: .regularExpression) != nil else {
            throw AccountRegistrationError.invalidAccount
        }
        } else {
            guard code.utf16.count == 6 else { throw AccountInputError.invalidCode }
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
