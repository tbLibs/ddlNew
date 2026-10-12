import Foundation

// 编译真实注册服务与 ViewModel，只替换 SDK 和 App 环境，不进行外部请求。
struct AccountLoginResponse: Sendable { var isValid = true }
struct RegistrationConfiguration {
    var registerMethod = "1"
    var isMustInviteCode = "0"
    var checkEnglishSymbol = false
}
@MainActor final class IMConnectionCoordinator {
    static let shared = IMConnectionCoordinator()
    var loginConnectionID: UUID? = UUID()
    var configuration: RegistrationConfiguration? = RegistrationConfiguration()
}
enum LXChatEncrypt { static func method4(_ value: String) -> String? { "fixture-cipher" } }
typealias SDKAccountRegistrationClient = RegistrationDriver
typealias LoginSessionService = RegistrationSession
@MainActor enum AppSessionRouter { static func enterMain() {} }

@MainActor final class RegistrationDriver: AccountRegistrationSDKDriving {
    var exists = false
    var key = "new-key"
    var response = AccountLoginResponse()
    var calls: [String] = []
    var parameters: [String: Any] = [:]
    var afterCheck: () -> Void = {}
    var afterKey: () -> Void = {}
    var afterRegister: () -> Void = {}
    var registerError: Error?
    var suspendCheck = false

    func checkAccountExists(account: String) async throws -> Bool {
        calls.append("check:\(account)")
        if suspendCheck { try await Task.sleep(nanoseconds: 5_000_000_000) }
        afterCheck()
        return exists
    }
    func fetchEncryptKey() async throws -> String {
        calls.append("key")
        afterKey()
        return key
    }
    func register(parameters: [String: Any]) async throws -> AccountLoginResponse {
        calls.append("register")
        self.parameters = parameters
        afterRegister()
        if let registerError { throw registerError }
        return response
    }
}

@MainActor final class RegistrationSession: LoginSessionServicing {
    static let shared = RegistrationSession()
    var calls = 0
    var cancelled = 0
    var complete = false
    var shouldSuspend = false
    var authError: Error?
    func completeLogin(_ response: AccountLoginResponse, account: String,
                       progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws {
        calls += 1
        progress(.savingSession)
        if shouldSuspend { try await Task.sleep(nanoseconds: 5_000_000_000) }
        progress(.authenticating)
        if let authError { throw authError }
        complete = true
    }
    func cancelPendingLogin() { cancelled += 1 }
    func clearSession() throws {}
}

@MainActor final class RegistrationFixture {
    let driver = RegistrationDriver()
    var context: AccountRegistrationContext? = AccountRegistrationContext(connectionID: UUID(), registerMethod: "1",
        requiresInviteCode: true, requiresPasswordSymbol: false)
    var encrypted: [String] = []
    lazy var service = AccountRegistrationService(driver: driver, context: { self.context }, encrypt: {
        self.encrypted.append($0)
        return "cipher"
    })
    var input: AccountRegistrationInput {
        AccountRegistrationInput(account: "Ab1234", password: "Ab1234", confirmation: "Ab1234", inviteCode: " invite ", acceptedPolicy: true)
    }
}

@main struct AccountRegistrationChecks {
    @MainActor static func main() async throws {
        try validateRules()
        try await parametersAndSequence()
        try await existingAccountStops()
        try await connectionIsolation()
        try await invalidKeyAndResponse()
        try await cancellation()
        try await sessionAndNavigation()
        try await registrationSurvivesAuthFailure()
        print("PASS: 账号注册输入、真实协议、连接隔离、取消和 AUTH 跳转时序")
    }

    static func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
        if !value() { throw NSError(domain: "RegistrationChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    @MainActor static func validateRules() throws {
        let fixture = RegistrationFixture()
        let context = fixture.context!
        try fixture.input.validate(in: context)
        for account in ["123456", "A12345", "Ab12", "Ab_123", "Ab12345678901234567", " Ab1234 "] {
            do {
                try AccountRegistrationInput(account: account, password: "Ab1234", confirmation: "Ab1234", inviteCode: "yes", acceptedPolicy: true).validate(in: context)
                throw TestFailure.unexpectedSuccess
            } catch is AccountRegistrationError {}
        }
        for password in ["abcdef", "123456", "Ab12", "Ab1234 ", "Ab123😀", "Ab123()"] {
            do {
                try AccountRegistrationInput(account: "Ab1234", password: password, confirmation: password, inviteCode: "yes", acceptedPolicy: true).validate(in: context)
                throw TestFailure.unexpectedSuccess
            } catch is AccountRegistrationError {}
        }
        let symbolContext = AccountRegistrationContext(connectionID: UUID(), registerMethod: "1", requiresInviteCode: false, requiresPasswordSymbol: true)
        do { try fixture.input.validate(in: symbolContext); throw TestFailure.unexpectedSuccess }
        catch AccountRegistrationError.invalidPassword(let symbol) { try require(symbol, "符号策略必须生效") }
        try AccountRegistrationInput(account: "Ab1234", password: "Ab123!", confirmation: "Ab123!", inviteCode: "", acceptedPolicy: true).validate(in: symbolContext)
        do {
            try AccountRegistrationInput(account: "Ab1234", password: "Ab1234", confirmation: "different", inviteCode: "yes", acceptedPolicy: true).validate(in: context)
            throw TestFailure.unexpectedSuccess
        } catch AccountRegistrationError.passwordMismatch {}
        do {
            try AccountRegistrationInput(account: "Ab1234", password: "Ab1234", confirmation: "Ab1234", inviteCode: "  ", acceptedPolicy: true).validate(in: context)
            throw TestFailure.unexpectedSuccess
        } catch AccountRegistrationError.inviteCodeRequired {}
        for method in ["1", "5", "6", "7", ""] {
            try require(AccountRegistrationContext(connectionID: UUID(), registerMethod: method, requiresInviteCode: false, requiresPasswordSymbol: false).allowsAccountRegistration, "允许账号组合必须开放")
        }
        for method in ["2", "3", "4"] {
            try require(!AccountRegistrationContext(connectionID: UUID(), registerMethod: method, requiresInviteCode: false, requiresPasswordSymbol: false).allowsAccountRegistration, "纯手机邮箱组合必须关闭")
        }
    }

    @MainActor static func parametersAndSequence() async throws {
        let fixture = RegistrationFixture()
        let result = try await fixture.service.register(fixture.input) { _ in }
        try require(result.isValid, "注册响应应返回")
        try require(fixture.driver.calls == ["check:Ab1234", "key", "register"], "必须先检查账号并取新key")
        try require(fixture.encrypted == ["new-keyAb1234"], "必须加密key拼接密码")
        let p = fixture.driver.parameters
        try require(p["loginInfo"] as? String == "Ab1234" && p["loginType"] as? Int == 1, "必须使用账号注册")
        try require(p["type"] as? Int == 1 && p["registerType"] as? Int == 1, "注册type必须是1")
        try require(p["code"] as? String == "" && p["areaCode"] as? String == "", "账号注册不携带手机号验证码")
        try require(p["userPw"] as? String == "cipher" && p["encryptKey"] as? String == "new-key", "仅提交加密密码")
        try require(p["inviteCode"] as? String == "invite", "邀请码应按配置提交")
        let denied = AccountRegistrationInput(account: "Ab1234", password: "Ab1234", confirmation: "Ab1234", inviteCode: "yes", acceptedPolicy: false)
        let before = fixture.driver.calls
        do { _ = try await fixture.service.register(denied) { _ in }; throw TestFailure.unexpectedSuccess }
        catch AccountRegistrationError.policyRequired {}
        try require(fixture.driver.calls == before, "未同意政策不得发请求")
    }

    @MainActor static func existingAccountStops() async throws {
        let fixture = RegistrationFixture()
        fixture.driver.exists = true
        do { _ = try await fixture.service.register(fixture.input) { _ in }; throw TestFailure.unexpectedSuccess }
        catch AccountRegistrationError.accountExists {}
        try require(fixture.driver.calls == ["check:Ab1234"], "已有账号不得取key或提交")
    }

    @MainActor static func connectionIsolation() async throws {
        for step in ["check", "key", "register"] {
            let fixture = RegistrationFixture()
            let change = { fixture.context = nil }
            if step == "check" { fixture.driver.afterCheck = change }
            if step == "key" { fixture.driver.afterKey = change }
            if step == "register" {
                fixture.driver.afterRegister = change
                fixture.driver.registerError = AccountLoginError.businessFailure(code: 42, message: "旧错误")
            }
            do { _ = try await fixture.service.register(fixture.input) { _ in }; throw TestFailure.unexpectedSuccess }
            catch AccountLoginError.connectionChanged {}
            try require(!fixture.driver.calls.contains("register") || step == "register", "连接切换后不得提交")
        }
    }

    @MainActor static func invalidKeyAndResponse() async throws {
        let fixture = RegistrationFixture()
        fixture.driver.key = ""
        do { _ = try await fixture.service.register(fixture.input) { _ in }; throw TestFailure.unexpectedSuccess }
        catch AccountLoginError.invalidEncryptKey {}
        try require(fixture.encrypted.isEmpty, "空key不能加密")
        fixture.driver.key = "valid"
        fixture.driver.response = AccountLoginResponse(isValid: false)
        do { _ = try await fixture.service.register(fixture.input) { _ in }; throw TestFailure.unexpectedSuccess }
        catch AccountLoginError.invalidResponse {}
    }

    @MainActor static func cancellation() async throws {
        let fixture = RegistrationFixture()
        fixture.driver.suspendCheck = true
        let task = Task { try await fixture.service.register(fixture.input) { _ in } }
        await Task.yield()
        task.cancel()
        do { _ = try await task.value; throw TestFailure.unexpectedSuccess }
        catch is CancellationError {}
        try require(!fixture.driver.calls.contains("register"), "取消后不能注册")
    }

    @MainActor static func sessionAndNavigation() async throws {
        let fixture = RegistrationFixture()
        let session = RegistrationSession()
        var navigations = 0
        let vm = AccountRegistrationViewModel(service: fixture.service, session: session, onSucceeded: {
            precondition(session.complete)
            navigations += 1
        })
        vm.register(fixture.input)
        vm.register(fixture.input)
        for _ in 0..<100 where vm.phase.isBusy { await Task.yield() }
        try require(vm.phase == .succeeded && navigations == 1 && session.calls == 1, "重复点击必须隔离且AUTH后才能跳转")
        vm.cancel()
        try require(session.cancelled == 0, "完成会话不可被退出页面取消")

        let pendingFixture = RegistrationFixture()
        let pendingSession = RegistrationSession()
        pendingSession.shouldSuspend = true
        let pending = AccountRegistrationViewModel(service: pendingFixture.service, session: pendingSession, onSucceeded: { navigations += 1 })
        pending.register(pendingFixture.input)
        for _ in 0..<100 where pendingSession.calls == 0 { await Task.yield() }
        try require(pending.phase == .savingSession, "取消测试必须进入会话建立阶段")
        pending.cancel()
        for _ in 0..<10 { await Task.yield() }
        try require(pending.phase == .idle && pendingSession.cancelled == 1 && navigations == 1, "取消注册必须停止pending会话和跳转")
    }

    @MainActor static func registrationSurvivesAuthFailure() async throws {
        let fixture = RegistrationFixture()
        let session = RegistrationSession()
        session.authError = AccountLoginError.timedOut
        var navigated = false
        let vm = AccountRegistrationViewModel(service: fixture.service, session: session, onSucceeded: { navigated = true })
        vm.register(fixture.input)
        for _ in 0..<100 where vm.phase.isBusy { await Task.yield() }
        guard case .failed(let message) = vm.phase else { throw TestFailure.unexpectedSuccess }
        try require(vm.accountWasRegistered && !navigated && message.contains("账号已注册"), "注册成功但AUTH失败须引导返回登录")
        vm.register(fixture.input)
        try require(fixture.driver.calls.filter { $0 == "register" }.count == 1, "不能重复创建已注册账号")
    }
    enum TestFailure: Error { case unexpectedSuccess }
}
