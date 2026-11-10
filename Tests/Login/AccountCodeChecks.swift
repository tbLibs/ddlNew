import Foundation

@MainActor final class IMConnectionCoordinator { static let shared = IMConnectionCoordinator(); var loginConnectionID: UUID? = UUID() }
typealias SDKAccountCodeClient = CodeDriver
@MainActor enum LoginVerificationCoordinator { static let shared = CodePresenter() }
@MainActor final class CodeDriver: AccountCodeSDKDriving {
    var calls: [String] = [], params: [[String: Any]] = []
    var registered = false
    var failures: [AccountLoginError] = []
    var afterImage: () -> Void = {}
    var afterSend: () -> Void = {}
    func restoreChannel(_ channel: Int) {}
    func isRegistered(_ identity: AccountIdentity) async throws -> Bool { calls.append("exists:\(identity.kind.rawValue)"); return registered }
    func image(account: String, type: Int) async throws -> Data { calls.append("image:\(type)"); afterImage(); return Data([1]) }
    func send(parameters: [String: Any], channel: Int) async throws {
        calls.append("send:\(channel)"); params.append(parameters); afterSend()
        if !failures.isEmpty { throw failures.removeFirst() }
    }
}
@MainActor final class CodePresenter: AccountLoginChallengePresenting {
    var requests: [LoginVerificationRequest] = []
    var answers: [LoginVerificationAnswer] = []
    var inspectRequest: ((LoginVerificationRequest) async throws -> Void)?
    func present(_ request: LoginVerificationRequest) async throws -> LoginVerificationAnswer {
        requests.append(request)
        try await inspectRequest?(request)
        return answers.isEmpty ? LoginVerificationAnswer(imageCode: "1234", captchaVerifyParam: "fixture") : answers.removeFirst()
    }
}
@MainActor final class CodeServiceFake: AccountCodeServicing {
    var calls = 0, fail = false, suspended = false
    var pending: CheckedContinuation<Void, Never>?
    func send(to identity: AccountIdentity, purpose: AccountCodePurpose) async throws {
        calls += 1
        if suspended { await withCheckedContinuation { pending = $0 } }
        if fail { throw AccountLoginError.timedOut }
    }
}
@main struct AccountCodeChecks {
    @MainActor static func drain() async { for _ in 0..<30 { await Task.yield() } }
    @MainActor static func main() async throws {
        let phone = AccountIdentity(kind: .phone, value: "13800138000", areaCode: "+852")
        let bermuda = AccountIdentity(kind: .phone, value: "5550123", areaCode: "+1-441")
        try bermuda.validate()
        precondition(bermuda.parameters["areaCode"] as? String == "+1-441")
        var connection = AccountLoginContext(connectionID: UUID(), loginMethod: "7", captchaChannel: 2)
        let driver = CodeDriver(), presenter = CodePresenter()
        let service = AccountCodeService(driver: driver, context: { connection }, presenter: presenter)
        presenter.inspectRequest = { request in
            guard let reload = request.reloadImage else { preconditionFailure("Missing refresh") }
            _ = try await reload()
        }
        try await service.send(to: phone, purpose: .registration)
        precondition(driver.calls == ["exists:3", "image:1", "image:1", "send:2"])
        presenter.inspectRequest = nil
        precondition(driver.params[0]["areaCode"] as? String == "+852" && driver.params[0]["type"] as? Int == 1 && driver.params[0]["code"] as? String == "1234")
        driver.calls = []; driver.params = []
        driver.calls = []; try await service.send(to: phone, purpose: .login)
        precondition(driver.calls == ["image:2", "send:2"])
        driver.calls = []; driver.registered = true
        do { try await service.send(to: phone, purpose: .registration); preconditionFailure() } catch AccountInputError.alreadyRegistered {}
        precondition(driver.calls == ["exists:3"])
        driver.registered = false; driver.calls = []
        driver.afterImage = { connection = AccountLoginContext(connectionID: UUID(), loginMethod: "7", captchaChannel: 2) }
        do { try await service.send(to: phone, purpose: .login); preconditionFailure() } catch AccountLoginError.connectionChanged {}
        precondition(driver.calls == ["image:2"])
        driver.afterImage = {}; driver.calls = []; driver.failures = [.businessFailure(code: 50002, message: "")]
        try await service.send(to: phone, purpose: .login)
        precondition(driver.calls == ["image:2", "send:2", "image:2", "send:2"])
        driver.calls = []; presenter.requests = []
        driver.failures = [.businessFailure(code: 51002, message: "")]
        presenter.answers = [LoginVerificationAnswer(imageCode: "1234"), LoginVerificationAnswer(requestsImageFallback: true), LoginVerificationAnswer(imageCode: "5678")]
        try await service.send(to: phone, purpose: .login)
        precondition(presenter.requests.map(\.kind) == [.imageCaptcha, .aliyunCaptcha(interactive: true), .imageCaptcha])
        precondition(driver.calls == ["image:2", "send:2", "image:2", "send:2"])
        let fake = CodeServiceFake(); var now = Date(timeIntervalSince1970: 100)
        let model = AccountCodeViewModel(service: fake, now: { now })
        model.send(to: phone, purpose: .login, scope: "club"); await drain()
        precondition(model.remaining(for: phone, purpose: .login, scope: "club", at: now) == 60)
        model.send(to: phone, purpose: .login, scope: "club"); await drain(); precondition(fake.calls == 1)
        precondition(model.remaining(for: bermuda, purpose: .login, scope: "club", at: now) == 0)
        precondition(model.remaining(for: phone, purpose: .registration, scope: "club", at: now) == 0)
        precondition(model.remaining(for: phone, purpose: .login, scope: "other", at: now) == 0)
        now = now.addingTimeInterval(61); fake.fail = true
        model.send(to: phone, purpose: .login, scope: "club"); await drain()
        precondition(model.remaining(for: phone, purpose: .login, scope: "club", at: now) == 0 && model.feedback != nil)
        fake.fail = false; fake.suspended = true
        model.send(to: bermuda, purpose: .login, scope: "club"); await drain()
        model.cancel(); fake.pending?.resume(); fake.pending = nil; await drain()
        precondition(model.remaining(for: bermuda, purpose: .login, scope: "club", at: now) == 0 && model.feedback == nil)
        precondition(phone.credentialKey != AccountIdentity(kind: .phone, value: phone.value, areaCode: "86").credentialKey)
        print("Account code checks passed")
    }
}
