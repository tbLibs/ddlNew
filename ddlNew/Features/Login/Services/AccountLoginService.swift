//
//  AccountLoginService.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

/// 负责账号检查、获取加密密钥与登录请求；会话和 AUTH 由会话服务处理。
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
        },
        challengePresenter: LoginVerificationCoordinator.shared
    )

    private let driver: any AccountLoginSDKDriving
    private let context: @MainActor () -> AccountLoginContext?
    private let encrypt: @MainActor (String) throws -> String
    private let challengePresenter: (any AccountLoginChallengePresenting)?

    init(driver: any AccountLoginSDKDriving,
         context: @escaping @MainActor () -> AccountLoginContext?,
         encrypt: @escaping @MainActor (String) throws -> String,
         challengePresenter: (any AccountLoginChallengePresenting)? = nil) {
        self.driver = driver
        self.context = context
        self.encrypt = encrypt
        self.challengePresenter = challengePresenter
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
        defer {
            // 本轮结束后恢复验证码渠道；连接变化时保留新俱乐部的配置。
            if context() == originalContext { driver.restoreCaptchaChannel(originalContext.captchaChannel) }
        }

        progress(.checkingAccount)
        try check(originalContext)
        debugPrint("[账号登录] 开始检查账号是否存在")
        let accountExists: Bool
        do {
            accountExists = try await driver.checkAccountExists(account: account)
            try check(originalContext)
        } catch {
            try check(originalContext)
            throw error
        }
        // 旧项目在 userExit=false 时提示 2036，不继续领取密钥或提交登录。
        guard accountExists else { throw AccountLoginError.businessFailure(code: 2036, message: "") }

        var answer = LoginVerificationAnswer()
        var captchaChannel = originalContext.captchaChannel
        var verificationAttempts = 0
        while true {
            let encryptKey = try await freshKey(originalContext, progress: progress)
            let userPw = try encrypt(encryptKey + password)
            guard !userPw.isEmpty else { throw AccountLoginError.encryptionFailed }
            let parameters: [String: Any] = [
                "loginInfo": account, "loginType": 1, "areaCode": "", "type": 2,
                "encryptKey": encryptKey, "userPw": userPw,
                "loginFailVerifyCode": answer.imageCode, "ticket": answer.ticket,
                "randstr": answer.randstr, "captchaVerifyParam": answer.captchaVerifyParam,
                "code": ""
            ]
            progress(.submitting)
            try check(originalContext)
            do {
                let response = try await driver.submit(parameters: parameters, captchaChannel: captchaChannel)
                try check(originalContext)
                guard response.isValid else { throw AccountLoginError.invalidResponse }
                return response
            } catch {
                // 失败回调也要核对连接轮次，避免为新俱乐部继续旧账号的验证。
                try check(originalContext)
                guard case let AccountLoginError.businessFailure(code, message) = error else { throw error }
                if code == 10009 {
                    guard !message.isEmpty else { throw AccountLoginError.securityVerificationExpired }
                    return try await verifySecurityCode(scKey: message, originalContext: originalContext,
                                                        verificationAttempts: &verificationAttempts,
                                                        progress: progress)
                }
                let kind: LoginVerificationKind
                switch code {
                case 40064, 50002:
                    switch captchaChannel {
                    case 2: kind = .imageCaptcha
                    case 3: kind = .tencentCaptcha
                    case 4: kind = .aliyunCaptcha(interactive: false)
                    default: throw AccountLoginError.verificationUnavailable
                    }
                case 51002: kind = .aliyunCaptcha(interactive: true)
                case 51006, 450010: kind = .imageCaptcha
                default: throw error
                }
                answer = try await present(kind: kind, account: account,
                                           message: code == 450010 || code == 50002 ? "验证码不正确，请重新验证" : "请完成验证码验证",
                                           originalContext: originalContext,
                                           verificationAttempts: &verificationAttempts,
                                           progress: progress)
                // 与旧项目一致，图文回退请求使用渠道 2，原俱乐部配置仍用于校验连接。
                if kind == .imageCaptcha { captchaChannel = 2 }
                else if case .aliyunCaptcha = kind { captchaChannel = 4 }
            }
        }
    }

    /// 每次密码或安全码提交前重新领取密钥；密钥只保留到本轮请求结束。
    private func freshKey(_ originalContext: AccountLoginContext,
                          progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> String {
        progress(.fetchingKey)
        try check(originalContext)
        do {
            let key = try await driver.fetchEncryptKey()
            try check(originalContext)
            guard !key.isEmpty else { throw AccountLoginError.invalidEncryptKey }
            return key
        } catch {
            try check(originalContext)
            throw error
        }
    }

    private func present(kind: LoginVerificationKind, account: String, message: String,
                         originalContext: AccountLoginContext, verificationAttempts: inout Int,
                         progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> LoginVerificationAnswer {
        guard verificationAttempts < 3 else { throw AccountLoginError.verificationAttemptsExceeded }
        guard let challengePresenter else { throw AccountLoginError.verificationUnavailable }
        verificationAttempts += 1
        progress(.verifying)
        try check(originalContext)
        var imageData: Data?
        if kind == .imageCaptcha {
            do {
                imageData = try await driver.fetchImageCaptcha(account: account)
                try check(originalContext)
                guard imageData?.isEmpty == false else { throw AccountLoginError.invalidResponse }
            } catch {
                try check(originalContext)
                throw error
            }
        }
        try check(originalContext)
        do {
            var answer = try await challengePresenter.present(LoginVerificationRequest(kind: kind, message: message, imageData: imageData))
            try check(originalContext)
            switch kind {
            case .imageCaptcha:
                answer.imageCode = answer.imageCode.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !answer.imageCode.isEmpty else { throw AccountLoginError.invalidVerificationAnswer }
                return LoginVerificationAnswer(imageCode: answer.imageCode)
            case .tencentCaptcha:
                guard !answer.ticket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !answer.randstr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AccountLoginError.invalidVerificationAnswer
                }
                return LoginVerificationAnswer(ticket: answer.ticket, randstr: answer.randstr)
            case .aliyunCaptcha:
                guard !answer.captchaVerifyParam.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AccountLoginError.invalidVerificationAnswer
                }
                return LoginVerificationAnswer(captchaVerifyParam: answer.captchaVerifyParam)
            case .securityCode:
                answer.securityCode = answer.securityCode.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !answer.securityCode.isEmpty else { throw AccountLoginError.invalidVerificationAnswer }
                return LoginVerificationAnswer(securityCode: answer.securityCode)
            }
        } catch {
            try check(originalContext)
            throw error
        }
    }

    /// scKey 仅在服务内部传给 SDK；不交给验证页面、不记录、不持久化。
    /// 错误安全码允许有限重试；过期或设备不匹配则结束验证，要求重新密码登录。
    private func verifySecurityCode(scKey: String, originalContext: AccountLoginContext,
                                    verificationAttempts: inout Int,
                                    progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> AccountLoginResponse {
        var message = "在新设备登录需要验证，请输入设备安全码"
        while true {
            let answer = try await present(kind: .securityCode, account: "", message: message,
                                           originalContext: originalContext, verificationAttempts: &verificationAttempts,
                                           progress: progress)
            let key = try await freshKey(originalContext, progress: progress)
            let encrypted = try encrypt(key + answer.securityCode)
            guard !encrypted.isEmpty else { throw AccountLoginError.encryptionFailed }
            let parameters: [String: Any] = ["scKey": scKey, "encryptKey": key, "securityCode": encrypted]
            progress(.submitting)
            try check(originalContext)
            do {
                let response = try await driver.submitSecurityCode(parameters: parameters)
                try check(originalContext)
                guard response.isValid else { throw AccountLoginError.invalidResponse }
                return response
            } catch {
                try check(originalContext)
                guard case let AccountLoginError.businessFailure(code, failureMessage) = error else { throw error }
                switch code {
                case 40069, 40070, 40071:
                    message = "安全码不正确，请重新输入六位数字和字母组成的安全码"
                case 40072, 40073: throw AccountLoginError.securityVerificationExpired
                case 90018:
                    throw AccountLoginError.businessFailure(code: code, message: LoginSecurityNotice.whitelistAddress(from: failureMessage))
                default:
                    // 安全验证响应可能包含临时凭据，页面仅显示固定提示。
                    throw AccountLoginError.businessFailure(code: code, message: "安全码验证失败，请重新登录")
                }
            }
        }
    }

    private func check(_ originalContext: AccountLoginContext) throws {
        try Task<Never, Never>.checkCancellation()
        guard context() == originalContext else { throw AccountLoginError.connectionChanged }
    }
}
