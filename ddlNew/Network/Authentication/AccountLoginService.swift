//
//  AccountLoginService.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

/// 请求进度与 IM 连接状态分开；请求成功尚不代表进入已登录会话。
enum AccountLoginPhase: Equatable {
    case idle
    /// 领取本次密码加密所需的一次性密钥。
    case fetchingKey
    /// 已生成密码密文，等待登录接口返回。
    case submitting
    /// 后续会话保存与 TCP 用户认证尚未接入。
    case succeeded
    case failed(String)

    var isBusy: Bool { self == .fetchingKey || self == .submitting }
    var buttonTitle: String {
        switch self {
        case .fetchingKey: return "正在获取加密密钥…"
        case .submitting: return "正在登录…"
        default: return "登录"
        }
    }
}

/// 保留 SDK 业务码供后续验证码、安全验证页面分流。
nonisolated enum AccountLoginError: LocalizedError {
    case emptyAccount
    case emptyPassword
    case connectionNotReady
    case connectionChanged
    case unsupportedAccountLogin
    case invalidEncryptKey
    case encryptionFailed
    case invalidResponse
    case unavailableOnSimulator
    case timedOut
    case businessFailure(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .emptyAccount: return "请输入会员卡号"
        case .emptyPassword: return "请输入密码"
        case .connectionNotReady: return "连接尚未就绪，请稍后重试"
        case .connectionChanged: return "连接已发生变化，请重新登录"
        case .unsupportedAccountLogin: return "当前俱乐部未开启账号密码登录"
        case .invalidEncryptKey: return "获取加密密钥失败，请重新登录"
        case .encryptionFailed: return "密码加密失败，请重试"
        case .invalidResponse: return "登录响应数据不完整，请重试"
        case .unavailableOnSimulator: return "密码加密需要真机运行"
        case .timedOut: return "登录请求超时，请重试"
        case .businessFailure(let code, let message):
            // 不绕过服务端校验；验证码和安全码页面在下一阶段接入。
            switch code {
            case 2036, 40019, 50000, 50001:
                return "账号或密码错误，请重新输入（\(code)）"
            case 40064, 50002, 51002, 51006, 450010:
                return "需要完成验证码验证（\(code)），验证码流程尚未接入"
            case 10009:
                return "需要安全码验证，安全验证流程尚未接入"
            default:
                return message.isEmpty ? "登录请求失败（\(code)）" : "\(message)（\(code)）"
            }
        }
    }
}

/// 记录真实连接轮次，不使用本地缓存存在与否判断登录是否可发起。
nonisolated struct AccountLoginContext: Equatable {
    let connectionID: UUID
    let loginMethod: String
    let captchaChannel: Int
}

@MainActor
protocol AccountLoginSDKDriving {
    func fetchEncryptKey() async throws -> String
    func submit(parameters: [String: Any], captchaChannel: Int) async throws -> AccountLoginResponse
}

@MainActor
protocol AccountLoginServicing {
    func login(account: String, password: String,
               progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> AccountLoginResponse
}

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
        debugPrint("[账号登录] 登录请求成功；会话处理尚未接入")
        return response
    }

    private func check(_ originalContext: AccountLoginContext) throws {
        try Task<Never, Never>.checkCancellation()
        guard context() == originalContext else { throw AccountLoginError.connectionChanged }
    }
}
