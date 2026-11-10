import Foundation

/// 支持账号和手机号；保留 xgd 协议值1、3，不重新编号。
nonisolated struct AccountIdentity: Hashable, Sendable {
    enum Kind: Int, CaseIterable, Codable, Sendable {
        case account = 1, phone = 3
        static var displayOrder: [Self] { [.account, .phone] }
        var title: String { switch self { case .account: return L10n.tr("账号"); case .phone: return L10n.tr("手机号") } }
        var missingCode: Int { switch self { case .account: return 2036; case .phone: return 50001 } }
        func allowed(by method: String) -> Bool {
            switch self {
            case .account: return ["1", "5", "6", "7"].contains(method)
            case .phone: return ["3", "4", "5", "7"].contains(method)
            }
        }
    }
    let kind: Kind
    let value: String
    let areaCode: String
    /// 短信验证码请求携带当前区号，默认+86。
    let verificationAreaCode: String

    init(kind: Kind = .account, value: String, areaCode: String = "86") {
        self.kind = kind
        self.value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedArea = areaCode.replacingOccurrences(of: "+", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.areaCode = kind == .phone ? normalizedArea : ""
        self.verificationAreaCode = "+\(normalizedArea.isEmpty ? "86" : normalizedArea)"
    }
    /// 仅用于本地凭据的归属键，绝不作为API的loginInfo；旧账号缓存保持兼容。
    var credentialKey: String { kind == .account ? value : "\(kind.rawValue):\(areaCode):\(value)" }
    var requestAreaCode: String { kind == .phone ? "+\(areaCode)" : "" }
    var parameters: [String: Any] { ["loginInfo": value, "loginType": kind.rawValue, "areaCode": requestAreaCode] }

    func validate() throws {
        switch kind {
        case .account:
            guard !value.isEmpty else { throw AccountLoginError.emptyAccount }
        case .phone:
            // xgd不限定国家手机号长度，最终号码有效性由服务端判断。
            guard value.range(of: "[0-9]", options: .regularExpression) != nil,
                  areaCode.range(of: "^[0-9]{1,4}(-[0-9]{1,4})?$", options: .regularExpression) != nil else { throw AccountInputError.invalidPhone }
        }
    }
}

nonisolated struct AccountLoginInput: Sendable {
    let identity: AccountIdentity
    var password = ""
    var code = ""
    var usesCode = false

    func validate() throws {
        try identity.validate()
        if identity.kind == .account, !(6...16).contains(identity.value.utf16.count) { throw AccountInputError.invalidAccountLength }
        if usesCode {
            guard identity.kind != .account, code.utf16.count == 6 else { throw AccountInputError.invalidCode }
        } else {
            guard !password.isEmpty else { throw AccountLoginError.emptyPassword }
            guard (6...16).contains(password.utf16.count) else { throw AccountInputError.invalidPasswordLength }
        }
    }
}

nonisolated enum AccountInputError: LocalizedError {
    case invalidPhone, invalidCode, alreadyRegistered, invalidAccountLength, invalidPasswordLength
    var errorDescription: String? {
        switch self {
        case .invalidPhone: return L10n.tr("请输入有效手机号并选择区号")
        case .invalidCode: return L10n.tr("请输入6位验证码")
        case .alreadyRegistered: return L10n.tr("该手机号已注册，请返回登录")
        case .invalidAccountLength: return L10n.tr("账号长度为6～16位")
        case .invalidPasswordLength: return L10n.tr("密码长度为6～16位")
        }
    }
}
