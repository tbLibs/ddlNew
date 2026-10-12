import Foundation

@MainActor
protocol AccountRegistrationServicing {
    func register(_ input: AccountRegistrationInput,
                  progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> AccountLoginResponse
}

/// 账号注册不发短信/邮箱验证码，参数 type=1 与旧项目一致。
@MainActor
final class AccountRegistrationService: AccountRegistrationServicing {
    static let shared = AccountRegistrationService(
        driver: SDKAccountRegistrationClient(),
        context: currentContext,
        encrypt: { value in
            #if targetEnvironment(simulator)
            throw AccountLoginError.unavailableOnSimulator
            #else
            guard let encrypted = LXChatEncrypt.method4(value), !encrypted.isEmpty else {
                throw AccountLoginError.encryptionFailed
            }
            return encrypted
            #endif
        }
    )

    static func currentContext() -> AccountRegistrationContext? {
        let connection = IMConnectionCoordinator.shared
        guard let id = connection.loginConnectionID, let configuration = connection.configuration else { return nil }
        return AccountRegistrationContext(connectionID: id, registerMethod: configuration.registerMethod,
                                          requiresInviteCode: configuration.isMustInviteCode != "0",
                                          requiresPasswordSymbol: configuration.checkEnglishSymbol)
    }

    private let driver: any AccountRegistrationSDKDriving
    private let context: @MainActor () -> AccountRegistrationContext?
    private let encrypt: @MainActor (String) throws -> String

    init(driver: any AccountRegistrationSDKDriving,
         context: @escaping @MainActor () -> AccountRegistrationContext?,
         encrypt: @escaping @MainActor (String) throws -> String) {
        self.driver = driver
        self.context = context
        self.encrypt = encrypt
    }

    func register(_ input: AccountRegistrationInput,
                  progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> AccountLoginResponse {
        try Task<Never, Never>.checkCancellation()
        guard let original = context() else { throw AccountLoginError.connectionNotReady }
        try input.validate(in: original)
        progress(.checkingAccount)
        let exists = try await checked(original) { try await self.driver.checkAccountExists(account: input.account) }
        guard !exists else { throw AccountRegistrationError.accountExists }
        progress(.fetchingKey)
        let key = try await checked(original) { try await self.driver.fetchEncryptKey() }
        guard !key.isEmpty else { throw AccountLoginError.invalidEncryptKey }
        let cipher = try encrypt(key + input.password)
        guard !cipher.isEmpty else { throw AccountLoginError.encryptionFailed }
        try check(original)
        let parameters: [String: Any] = [
            "loginInfo": input.account, "loginType": 1, "code": "", "encryptKey": key,
            "registerType": 1, "type": 1, "areaCode": "", "userPw": cipher,
            "inviteCode": original.requiresInviteCode ? input.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        ]
        progress(.submitting)
        let response = try await checked(original) { try await self.driver.register(parameters: parameters) }
        guard response.isValid else { throw AccountLoginError.invalidResponse }
        return response
    }

    /// 失败回调也要核对连接，避免切换俱乐部后继续旧请求。
    private func checked<Value>(_ original: AccountRegistrationContext,
                                operation: () async throws -> Value) async throws -> Value {
        try check(original)
        do {
            let value = try await operation()
            try check(original)
            return value
        } catch {
            try check(original)
            throw error
        }
    }

    private func check(_ original: AccountRegistrationContext) throws {
        try Task<Never, Never>.checkCancellation()
        guard context() == original else { throw AccountLoginError.connectionChanged }
    }
}
