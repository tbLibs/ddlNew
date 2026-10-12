import Foundation

// Compile the real login service on macOS; replace only SDK/platform dependencies.
struct AccountLoginResponse: Sendable { var isValid = true }
struct TestConfiguration { let loginMethod = "1"; let captchaChannel = 2 }
@MainActor final class IMConnectionCoordinator {
    static let shared = IMConnectionCoordinator()
    let loginConnectionID: UUID? = UUID()
    let configuration: TestConfiguration? = TestConfiguration()
}
enum LXChatEncrypt { static func method4(_ value: String) -> String? { "fixture-cipher" } }
typealias SDKAccountLoginClient = FakeLoginSDK

@MainActor final class FakeLoginSDK: AccountLoginSDKDriving {
    var exists = true
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
        return "fixture-key"
    }
    func submit(parameters: [String: Any], captchaChannel: Int) async throws -> AccountLoginResponse {
        calls.append("submit")
        submittedParameters = parameters
        if let error = submitError { throw error }
        return AccountLoginResponse()
    }
}

@MainActor final class LoginFixture {
    let driver = FakeLoginSDK()
    var connection = AccountLoginContext(connectionID: UUID(), loginMethod: "1", captchaChannel: 2)
    var encryptedValues: [String] = []
    lazy var service = AccountLoginService(driver: driver, context: { self.connection }, encrypt: {
        self.encryptedValues.append($0)
        return "fixture-cipher"
    })
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
            ("missing account returns 2036 before key/encryption/login", {
                let fixture = LoginFixture()
                fixture.driver.exists = false
                // Reproduce the observed login endpoint timeout if precheck is skipped.
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
