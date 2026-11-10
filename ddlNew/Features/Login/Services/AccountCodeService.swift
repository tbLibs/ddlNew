import Foundation

nonisolated enum AccountCodePurpose: Int, Sendable { case registration = 1, login = 2 }
@MainActor protocol AccountCodeSDKDriving {
    func isRegistered(_ identity: AccountIdentity) async throws -> Bool
    func image(account: String, type: Int) async throws -> Data
    func send(parameters: [String: Any], channel: Int) async throws
    func restoreChannel(_ channel: Int)
}
@MainActor protocol AccountCodeServicing {
    func send(to identity: AccountIdentity, purpose: AccountCodePurpose) async throws
}

/// 手机先完成图文/第三方验证；回包仍受原连接身份保护。
@MainActor final class AccountCodeService: AccountCodeServicing {
    static let shared = AccountCodeService(driver: SDKAccountCodeClient(), context: {
        guard let id = IMConnectionCoordinator.shared.loginConnectionID else { return nil }
        return AccountLoginContext(connectionID: id, loginMethod: LocalAccountPolicy.loginMethod, captchaChannel: LocalAccountPolicy.captchaChannel)
    }, presenter: LoginVerificationCoordinator.shared)
    private let driver: any AccountCodeSDKDriving
    private let context: () -> AccountLoginContext?
    private let presenter: any AccountLoginChallengePresenting
    init(driver: any AccountCodeSDKDriving, context: @escaping () -> AccountLoginContext?, presenter: any AccountLoginChallengePresenting) {
        self.driver = driver; self.context = context; self.presenter = presenter
    }
    func send(to identity: AccountIdentity, purpose: AccountCodePurpose) async throws {
        try identity.validate()
        guard identity.kind != .account else { throw AccountLoginError.verificationUnavailable }
        guard let original = context() else { throw AccountLoginError.connectionNotReady }
        defer { if context() == original { driver.restoreChannel(original.captchaChannel) } }
        try check(original)
        if purpose == .registration {
            let exists: Bool
            do { exists = try await driver.isRegistered(identity); try check(original) }
            catch { try check(original); throw error }
            guard !exists else { throw AccountInputError.alreadyRegistered }
        }
        var channel = original.captchaChannel
        var challenge: LoginVerificationKind?
        if identity.kind == .phone {
            switch channel {
            case 1: break
            case 2: challenge = .imageCaptcha
            case 3: challenge = .tencentCaptcha
            case 4: challenge = .aliyunCaptcha(interactive: false)
            default: throw AccountLoginError.verificationUnavailable
            }
        }
        for _ in 0..<3 {
            try check(original)
            var answer = LoginVerificationAnswer()
            if let currentChallenge = challenge {
                let image: Data?
                do { image = currentChallenge == .imageCaptcha ? try await driver.image(account: identity.value, type: purpose.rawValue) : nil; try check(original) }
                catch { try check(original); throw error }
                var reloadImage: (@MainActor () async throws -> Data)?
                if currentChallenge == .imageCaptcha {
                    reloadImage = { @MainActor () async throws -> Data in
                        try self.check(original)
                        do {
                            let data = try await self.driver.image(account: identity.value, type: purpose.rawValue)
                            try self.check(original)
                            guard !data.isEmpty else { throw AccountLoginError.invalidResponse }
                            return data
                        } catch { try self.check(original); throw error }
                    }
                }
                answer = try await presenter.present(LoginVerificationRequest(kind: currentChallenge, message: "完成验证后发送验证码", imageData: image,
                    title: "安全验证", submitTitle: "验证并发送", reloadImage: reloadImage))
                try check(original)
                if answer.requestsImageFallback {
                    switch currentChallenge {
                    case .tencentCaptcha, .aliyunCaptcha: break
                    default: throw AccountLoginError.invalidVerificationAnswer
                    }
                    // 由下一轮重新获取图片；不能把服务商失败当作验证成功发送。
                    challenge = .imageCaptcha
                    continue
                }
                switch currentChallenge {
                case .imageCaptcha:
                    answer.imageCode = answer.imageCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !answer.imageCode.isEmpty else { throw AccountLoginError.invalidVerificationAnswer }; channel = 2
                case .tencentCaptcha:
                    guard !answer.ticket.isEmpty && !answer.randstr.isEmpty else { throw AccountLoginError.invalidVerificationAnswer }; channel = 3
                case .aliyunCaptcha:
                    guard !answer.captchaVerifyParam.isEmpty else { throw AccountLoginError.invalidVerificationAnswer }; channel = 4
                case .securityCode: throw AccountLoginError.verificationUnavailable
                }
            }
            var parameters = identity.parameters
            parameters["areaCode"] = identity.verificationAreaCode
            parameters.merge(["type": purpose.rawValue, "code": answer.imageCode, "ticket": answer.ticket,
                              "randstr": answer.randstr, "captchaVerifyParam": answer.captchaVerifyParam]) { _, new in new }
            do { try await driver.send(parameters: parameters, channel: channel); try check(original); return }
            catch {
                try check(original)
                guard case let AccountLoginError.businessFailure(code, _) = error else { throw error }
                switch code {
                case 51002: challenge = .aliyunCaptcha(interactive: true)
                case 40064, 50002, 51006, 450010: challenge = .imageCaptcha
                default: throw error
                }
            }
        }
        throw AccountLoginError.verificationAttemptsExceeded
    }
    private func check(_ original: AccountLoginContext) throws {
        try Task.checkCancellation()
        guard context() == original else { throw AccountLoginError.connectionChanged }
    }
}
