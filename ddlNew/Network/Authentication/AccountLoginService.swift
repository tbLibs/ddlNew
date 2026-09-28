//
//  AccountLoginService.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

/// 只负责“账号密码 → 加密密钥 → 登录请求”，不配置已登录用户、不跳转、不保存会话。
@MainActor
final class AccountLoginService: AccountLoginServicing {
    static let shared = AccountLoginService(
        driver: SDKAccountLoginClient(),
        context: {
            let connection = IMConnectionCoordinator.shared
            guard let id = connection.loginConnectionID,
                  let configuration = connection.configuration else { return nil }
            return AccountLoginContext(connectionID: id, loginMethod: configuration.loginMethod,
                                       captchaChannel: configuration.captchaChannel)
        },
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

    private let driver: any AccountLoginSDKDriving
    private let context: @MainActor () -> AccountLoginContext?
    private let encrypt: @MainActor (String) throws -> String

    init(driver: any AccountLoginSDKDriving,
         context: @escaping @MainActor () -> AccountLoginContext?,
         encrypt: @escaping @MainActor (String) throws -> String) {
        self.driver = driver
        self.context = context
        self.encrypt = encrypt
    }

    func login(account: String, password: String,
               progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> AccountLoginResponse {
        try Task<Never, Never>.checkCancellation()
        let account = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty else { throw AccountLoginError.emptyAccount }
        // 密码不能 trim；前后空格可能属于用户真实密码。
        guard !password.isEmpty else { throw AccountLoginError.emptyPassword }
        guard let originalContext = context() else { throw AccountLoginError.connectionNotReady }
        // 对应旧项目账号登录组合，不把邮箱/手机号误作账号登录。
        guard ["1", "5", "6", "7"].contains(originalContext.loginMethod) else {
            throw AccountLoginError.unsupportedAccountLogin
        }

        progress(.fetchingKey)
        try check(originalContext)
        debugPrint("[账号登录] 开始获取加密密钥")
        let encryptKey = try await driver.fetchEncryptKey()
        try check(originalContext)
        guard !encryptKey.isEmpty else { throw AccountLoginError.invalidEncryptKey }
        // 密钥只用于本次请求，重试必须重新领取，不缓存、不自动复用。
        let userPw = try encrypt(encryptKey + password)
        guard !userPw.isEmpty else { throw AccountLoginError.encryptionFailed }
        try check(originalContext)

        let parameters: [String: Any] = [
            "loginInfo": account, "loginType": 1, "areaCode": "", "type": 2,
            "encryptKey": encryptKey, "userPw": userPw,
            "loginFailVerifyCode": "", "ticket": "", "randstr": "",
            "captchaVerifyParam": "", "code": ""
        ]
        progress(.submitting)
        try check(originalContext)
        debugPrint("[账号登录] 密码已加密，开始发送登录请求")
        let response = try await driver.submit(parameters: parameters, captchaChannel: originalContext.captchaChannel)
        try check(originalContext)
        guard response.isValid else { throw AccountLoginError.invalidResponse }
        debugPrint("[账号登录] 登录请求成功，开始处理用户会话")
        return response
    }

    private func check(_ originalContext: AccountLoginContext) throws {
        try Task<Never, Never>.checkCancellation()
        guard context() == originalContext else { throw AccountLoginError.connectionChanged }
    }
}
