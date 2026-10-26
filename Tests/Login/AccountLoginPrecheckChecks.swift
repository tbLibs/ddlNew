import Foundation

// 在 macOS 编译真实登录服务，仅替换 SDK 与平台依赖，验证实际请求顺序和分流行为。
struct AccountLoginResponse: Sendable { var isValid = true }
struct TestConfiguration { let loginMethod = "1"; let captchaChannel = 2 }
@MainActor final class IMConnectionCoordinator {
    static let shared = IMConnectionCoordinator()
    let loginConnectionID: UUID? = UUID()
    var configuration: TestConfiguration? = TestConfiguration()
}
enum LXChatEncrypt { static func method4(_ value: String) -> String? { "fixture-cipher" } }
typealias SDKAccountLoginClient = FakeLoginSDK
@MainActor enum LoginVerificationCoordinator { static let shared = FakeChallengePresenter() }

@MainActor final class FakeLoginSDK: AccountLoginSDKDriving {
    var exists = true
    var submitFailures: [AccountLoginError] = []
    var safeFailures: [AccountLoginError] = []
    var submittedChannels: [Int] = []
    var submissions: [[String: Any]] = []
    var safeSubmissions: [[String: Any]] = []
    var keyCount = 0
    var restoredChannels: [Int] = []
    func restoreCaptchaChannel(_ channel: Int) { restoredChannels.append(channel) }
    var afterImage: () -> Void = {}
    var afterKey: () -> Void = {}
    var afterSubmit: () -> Void = {}
    var afterSafe: () -> Void = {}
    var checkError: Error?
    var submitError: AccountLoginError?
    var afterCheck: () -> Void = {}
    var calls: [String] = []
    var checkedAccount: String?
    var submittedParameters: [String: Any] = [:]

    func checkAccountExists(account: String) async throws -> Bool {
        calls.append("check")
        checkedAccount = account
        afterCheck()
        if let error = checkError { throw error }
        return exists
    }
    func fetchEncryptKey() async throws -> String {
        calls.append("key")
        keyCount += 1
        afterKey()
        return keyCount == 1 ? "fixture-key" : "fixture-key-\(keyCount)"
    }
    func submit(parameters: [String: Any], captchaChannel: Int) async throws -> AccountLoginResponse {
        calls.append("submit")
        submittedParameters = parameters
        submissions.append(parameters)
        submittedChannels.append(captchaChannel)
        afterSubmit()
        if !submitFailures.isEmpty { throw submitFailures.removeFirst() }
        if let error = submitError { throw error }
        return AccountLoginResponse()
    }
    func fetchImageCaptcha(account: String) async throws -> Data {
        calls.append("image")
        afterImage()
        return Data([1, 2, 3])
    }
    func submitSecurityCode(parameters: [String: Any]) async throws -> AccountLoginResponse {
        calls.append("safe")
        safeSubmissions.append(parameters)
        afterSafe()
        if !safeFailures.isEmpty { throw safeFailures.removeFirst() }
        return AccountLoginResponse()
    }
}

@MainActor final class FakeChallengePresenter: AccountLoginChallengePresenting {
    var requests: [LoginVerificationRequest] = []
    var answers: [LoginVerificationAnswer] = []
    var error: Error?
    var afterPresent: () -> Void = {}
    func present(_ request: LoginVerificationRequest) async throws -> LoginVerificationAnswer {
        requests.append(request)
        afterPresent()
        if let error { throw error }
        return answers.isEmpty ? LoginVerificationAnswer() : answers.removeFirst()
    }
}

@MainActor final class LoginFixture {
    let driver = FakeLoginSDK()
    let presenter = FakeChallengePresenter()
    var connection = AccountLoginContext(connectionID: UUID(), loginMethod: "1", captchaChannel: 2)
    var encryptedValues: [String] = []
    lazy var service = AccountLoginService(driver: driver, context: { self.connection }, encrypt: {
        self.encryptedValues.append($0)
        return "fixture-cipher"
    }, challengePresenter: presenter)
    func login(account: String = "fixture-account", password: String = "fixture-password") async throws {
        _ = try await service.login(account: account, password: password, progress: { _ in })
    }
}

enum CheckFailure: Error { case assertion(String) }
@main struct LoginPrecheckChecks {
    @MainActor static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw CheckFailure.assertion(message) }
    }
    @MainActor static func expectCode(_ code: Int, fixture: LoginFixture) async throws {
        do {
            try await fixture.login()
            throw CheckFailure.assertion("Expected failure code \(code)")
        } catch AccountLoginError.businessFailure(let received, _) {
            try require(received == code, "Expected \(code), received \(received)")
        }
    }
    @MainActor static func main() async {
        var failures = 0
        let checks: [(String, @MainActor () async throws -> Void)] = [
            ("production login works without system configuration", {
                IMConnectionCoordinator.shared.configuration = nil
                defer { IMConnectionCoordinator.shared.configuration = TestConfiguration() }
                let response = try await AccountLoginService.shared.login(account: "Ab1234", password: "Ab1234") { _ in }
                try require(response.isValid, "Missing system config must not block account login")
            }),
            ("image challenge retries with new key and account image code", {
                let f = LoginFixture()
                f.driver.submitFailures = [.businessFailure(code: 40064, message: "")]
                f.presenter.answers = [LoginVerificationAnswer(imageCode: " 1234 ")]
                try await f.login()
                try require(f.presenter.requests.map(\.kind) == [.imageCaptcha], "Image challenge not presented")
                try require(f.presenter.requests[0].imageData == Data([1, 2, 3]), "Image not loaded")
                try require(f.driver.keyCount == 2, "Retry reused encryption key")
                try require(f.driver.submissions.last?["loginFailVerifyCode"] as? String == "1234", "Image answer not sent")
                try require(f.driver.submissions.last?["code"] as? String == "", "Account image code must use loginFailVerifyCode; code is empty in legacy")
            }),
            ("Tencent challenge forwards ticket and randstr", {
                let f = LoginFixture()
                f.connection = AccountLoginContext(connectionID: UUID(), loginMethod: "1", captchaChannel: 3)
                f.driver.submitFailures = [.businessFailure(code: 50002, message: "")]
                f.presenter.answers = [LoginVerificationAnswer(ticket: "ticket", randstr: "random")]
                try await f.login()
                try require(f.presenter.requests.map(\.kind) == [.tencentCaptcha], "Tencent challenge not used")
                try require(f.driver.submissions.last?["ticket"] as? String == "ticket", "Ticket missing")
                try require(f.driver.submissions.last?["randstr"] as? String == "random", "Random token missing")
            }),
            ("Ali transitions from initial to interactive verification", {
                let f = LoginFixture()
                f.connection = AccountLoginContext(connectionID: UUID(), loginMethod: "1", captchaChannel: 4)
                f.driver.submitFailures = [.businessFailure(code: 40064, message: ""), .businessFailure(code: 51002, message: "")]
                f.presenter.answers = [LoginVerificationAnswer(captchaVerifyParam: "first"), LoginVerificationAnswer(captchaVerifyParam: "interactive")]
                try await f.login()
                try require(f.presenter.requests.map(\.kind) == [.aliyunCaptcha(interactive: false), .aliyunCaptcha(interactive: true)], "Ali stages incorrect")
                try require(f.driver.submissions.last?["captchaVerifyParam"] as? String == "interactive", "Ali answer missing")
            }),
            ("Ali timeout and incorrect image force channel two", {
                for code in [51006, 450010] {
                    let f = LoginFixture()
                    f.connection = AccountLoginContext(connectionID: UUID(), loginMethod: "1", captchaChannel: 4)
                    f.driver.submitFailures = [.businessFailure(code: code, message: "")]
                    f.presenter.answers = [LoginVerificationAnswer(imageCode: "1234")]
                    try await f.login()
                    try require(f.driver.submittedChannels == [4, 2], "Image fallback did not use channel 2")
                    try require(f.connection.captchaChannel == 4, "Fallback changed original context")
                }
            }),
            ("security challenge hides key and encrypts trimmed code with fresh key", {
                let f = LoginFixture()
                f.driver.submitFailures = [.businessFailure(code: 10009, message: "secret-challenge-key")]
                f.presenter.answers = [LoginVerificationAnswer(securityCode: " safe01 ")]
                try await f.login()
                try require(f.presenter.requests.map(\.kind) == [.securityCode], "Security challenge missing")
                try require(!f.presenter.requests[0].message.contains("secret-challenge-key"), "Challenge key exposed")
                try require(f.encryptedValues == ["fixture-keyfixture-password", "fixture-key-2safe01"], "Security encryption wrong")
                try require(f.driver.safeSubmissions[0]["scKey"] as? String == "secret-challenge-key", "Security key missing")
                try require(f.driver.safeSubmissions[0]["securityCode"] as? String == "fixture-cipher", "Safe code sent in plaintext")
            }),
            ("wrong security code retries with fresh key", {
                let f = LoginFixture()
                f.driver.submitFailures = [.businessFailure(code: 10009, message: "secret-key")]
                f.driver.safeFailures = [.businessFailure(code: 40069, message: "")]
                f.presenter.answers = [LoginVerificationAnswer(securityCode: "wrong1"), LoginVerificationAnswer(securityCode: "right1")]
                try await f.login()
                try require(f.driver.keyCount == 3 && f.driver.safeSubmissions.count == 2, "Security retry missing fresh key")
            }),
            ("expired security challenge stops and prompts password login", {
                for code in [40072, 40073] {
                    let f = LoginFixture()
                    f.driver.submitFailures = [.businessFailure(code: 10009, message: "secret-key")]
                    f.driver.safeFailures = [.businessFailure(code: code, message: "secret-key")]
                    f.presenter.answers = [LoginVerificationAnswer(securityCode: "safe01")]
                    do { try await f.login(); throw CheckFailure.assertion("Stale security challenge accepted") }
                    catch let error as AccountLoginError {
                        try require(error.localizedDescription.contains("重新登录"), "No restart instruction")
                        try require(!error.localizedDescription.contains("secret-key"), "Security key exposed in error")
                    }
                    try require(f.driver.safeSubmissions.count == 1 && f.presenter.requests.count == 1, "Stale challenge retried")
                }
            }),
            ("challenge cancellation stops before new key", {
                let f = LoginFixture()
                f.driver.submitFailures = [.businessFailure(code: 40064, message: "")]
                f.presenter.error = CancellationError()
                do { try await f.login(); throw CheckFailure.assertion("Cancelled challenge accepted") }
                catch is CancellationError {}
                try require(f.driver.keyCount == 1, "Cancelled challenge fetched a new key")
            }),
            ("connection change during challenge stops before retry", {
                let f = LoginFixture()
                f.driver.submitFailures = [.businessFailure(code: 40064, message: "")]
                f.presenter.answers = [LoginVerificationAnswer(imageCode: "1234")]
                f.presenter.afterPresent = { f.connection = AccountLoginContext(connectionID: UUID(), loginMethod: "1", captchaChannel: 2) }
                do { try await f.login(); throw CheckFailure.assertion("Changed context accepted") }
                catch AccountLoginError.connectionChanged {}
                try require(f.driver.keyCount == 1, "Changed context fetched retry key")
            }),
            ("empty verification answer stops before retry", {
                let f = LoginFixture()
                f.driver.submitFailures = [.businessFailure(code: 40064, message: "")]
                do { try await f.login(); throw CheckFailure.assertion("Empty answer accepted") }
                catch AccountLoginError.invalidVerificationAnswer {}
                try require(f.driver.keyCount == 1 && f.presenter.requests.count == 1, "Empty answer retried login")
            }),
            ("verification retries are bounded", {
                let f = LoginFixture()
                f.driver.submitFailures = Array(repeating: .businessFailure(code: 50002, message: ""), count: 4)
                f.presenter.answers = Array(repeating: LoginVerificationAnswer(imageCode: "1234"), count: 4)
                do { try await f.login(); throw CheckFailure.assertion("Retry limit ignored") }
                catch is AccountLoginError {}
                try require(f.presenter.requests.count == 3 && f.driver.submissions.count == 4, "Verification attempt limit wrong")
            }),
            ("connection change during image fetch prevents presentation", {
                let f = LoginFixture()
                f.driver.submitFailures = [.businessFailure(code: 40064, message: "")]
                f.driver.afterImage = { f.connection = AccountLoginContext(connectionID: UUID(), loginMethod: "1", captchaChannel: 2) }
                do { try await f.login(); throw CheckFailure.assertion("Image fetch accepted changed context") }
                catch AccountLoginError.connectionChanged {}
                try require(f.presenter.requests.isEmpty, "Challenge presented after connection change")
            }),
            ("connection change during key fetch prevents password submission", {
                let f = LoginFixture()
                f.driver.afterKey = { f.connection = AccountLoginContext(connectionID: UUID(), loginMethod: "1", captchaChannel: 2) }
                do { try await f.login(); throw CheckFailure.assertion("Key accepted changed context") }
                catch AccountLoginError.connectionChanged {}
                try require(f.driver.submissions.isEmpty && f.encryptedValues.isEmpty, "Stale key consumed")
            }),
            ("connection change during failed password submit prevents challenge", {
                let f = LoginFixture()
                f.driver.submitFailures = [.businessFailure(code: 10009, message: "secret-key")]
                f.driver.afterSubmit = { f.connection = AccountLoginContext(connectionID: UUID(), loginMethod: "1", captchaChannel: 2) }
                do { try await f.login(); throw CheckFailure.assertion("Failed submit accepted changed context") }
                catch AccountLoginError.connectionChanged {}
                try require(f.presenter.requests.isEmpty, "Stale challenge presented")
            }),
            ("connection change during successful security submit rejects session", {
                let f = LoginFixture()
                f.driver.submitFailures = [.businessFailure(code: 10009, message: "secret-key")]
                f.presenter.answers = [LoginVerificationAnswer(securityCode: "safe01")]
                f.driver.afterSafe = { f.connection = AccountLoginContext(connectionID: UUID(), loginMethod: "1", captchaChannel: 2) }
                do { try await f.login(); throw CheckFailure.assertion("Stale safe response accepted") }
                catch AccountLoginError.connectionChanged {}
            }),
            ("security login preserves actual whitelist IP in failure", {
                let f = LoginFixture()
                f.driver.submitFailures = [.businessFailure(code: 10009, message: "fixture-scKey")]
                f.driver.safeFailures = [.businessFailure(code: 90018, message: "203.0.113.42")]
                f.presenter.answers = [LoginVerificationAnswer(securityCode: "safe01")]
                do { try await f.login(); throw CheckFailure.assertion("Whitelist rejection accepted") }
                catch let AccountLoginError.businessFailure(code, message) {
                    try require(code == 90018, "Whitelist code changed")
                    try require(message == "203.0.113.42", "Actual whitelist IP was discarded")
                }
            }),
            ("security retry limit prevents endless challenge loop", {
                let f = LoginFixture()
                f.driver.submitFailures = [.businessFailure(code: 10009, message: "secret-key")]
                f.driver.safeFailures = Array(repeating: .businessFailure(code: 40069, message: ""), count: 4)
                f.presenter.answers = Array(repeating: LoginVerificationAnswer(securityCode: "wrong1"), count: 4)
                do { try await f.login(); throw CheckFailure.assertion("Endless security loop") }
                catch AccountLoginError.verificationAttemptsExceeded {}
                try require(f.presenter.requests.count == 3 && f.driver.safeSubmissions.count == 3, "Safe attempt limit incorrect")
            }),
            ("image fallback remains on channel two after incorrect answer", {
                let f = LoginFixture()
                f.connection = AccountLoginContext(connectionID: UUID(), loginMethod: "1", captchaChannel: 4)
                f.driver.submitFailures = [.businessFailure(code: 51006, message: ""), .businessFailure(code: 50002, message: "")]
                f.presenter.answers = Array(repeating: LoginVerificationAnswer(imageCode: "1234"), count: 2)
                try await f.login()
                try require(f.presenter.requests.map(\.kind) == [.imageCaptcha, .imageCaptcha], "Fallback switched back to Ali")
                try require(f.driver.submittedChannels == [4, 2, 2], "Fallback lost channel 2")
            }),
            ("temporary image channel is restored when attempt finishes", {
                let f = LoginFixture()
                f.connection = AccountLoginContext(connectionID: UUID(), loginMethod: "1", captchaChannel: 4)
                f.driver.submitFailures = [.businessFailure(code: 51006, message: "")]
                f.presenter.answers = [LoginVerificationAnswer(imageCode: "1234")]
                try await f.login()
                try require(f.driver.restoredChannels == [4], "Temporary SDK channel not restored")
            }),
            ("missing account returns 2036 before key/encryption/login", {
                let fixture = LoginFixture()
                fixture.driver.exists = false
                // 跳过账号预检查时，复现曾观察到的登录接口超时。
                fixture.driver.submitError = .businessFailure(code: 0, message: "")
                try await expectCode(2036, fixture: fixture)
                try require(fixture.driver.calls == ["check"], "Missing account reached login endpoint")
                try require(fixture.encryptedValues.isEmpty, "Missing account consumed an encryption key")
            }),
            ("precheck business failure preserves 2036", {
                let fixture = LoginFixture()
                fixture.driver.checkError = AccountLoginError.businessFailure(code: 2036, message: "")
                try await expectCode(2036, fixture: fixture)
                try require(fixture.driver.calls == ["check"], "Precheck failure did not stop login")
            }),
            ("wrong password preserves 40019", {
                let fixture = LoginFixture()
                fixture.driver.submitError = .businessFailure(code: 40019, message: "")
                try await expectCode(40019, fixture: fixture)
                try require(fixture.driver.calls == ["check", "key", "submit"], "Wrong request order")
            }),
            ("existing account uses normal login and preserves password spaces", {
                let fixture = LoginFixture()
                try await fixture.login(account: "  fixture-account  ", password: " fixture-password ")
                try require(fixture.driver.calls == ["check", "key", "submit"], "Precheck must precede key/login")
                try require(fixture.driver.checkedAccount == "fixture-account", "Precheck account not normalized")
                try require(fixture.driver.submittedParameters["loginInfo"] as? String == "fixture-account", "Account changed after precheck")
                try require(fixture.encryptedValues == ["fixture-key fixture-password "], "Password was trimmed")
            }),
            ("connection change during precheck stops login", {
                let fixture = LoginFixture()
                fixture.driver.afterCheck = {
                    fixture.connection = AccountLoginContext(connectionID: UUID(), loginMethod: "1", captchaChannel: 2)
                }
                do {
                    try await fixture.login()
                    throw CheckFailure.assertion("Changed connection was accepted")
                } catch AccountLoginError.connectionChanged {}
                try require(fixture.driver.calls == ["check"], "Old connection continued to login")
            }),
            ("precheck cancellation stops login", {
                let fixture = LoginFixture()
                fixture.driver.checkError = CancellationError()
                do {
                    try await fixture.login()
                    throw CheckFailure.assertion("Cancelled precheck was accepted")
                } catch is CancellationError {}
                try require(fixture.driver.calls == ["check"], "Cancelled precheck continued to login")
            }),
            ("precheck transport failure remains distinct from missing account", {
                let fixture = LoginFixture()
                fixture.driver.checkError = AccountLoginError.businessFailure(code: 0, message: "")
                try await expectCode(0, fixture: fixture)
                try require(fixture.driver.calls == ["check"], "Transport failure continued to login")
            })
        ]
        for (name, check) in checks {
            do { try await check(); print("PASS: \(name)") }
            catch { failures += 1; print("FAIL: \(name): \(error)") }
        }
        print("\(checks.count - failures)/\(checks.count) checks passed")
        if failures > 0 { exit(1) }
    }
}
