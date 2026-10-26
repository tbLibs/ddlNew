import Foundation
import Combine

// 执行真实 LoginViewModel；替换外部登录、会话、Keychain 与路由边界。
struct UserInfo { let userUID: String }
struct AccountLoginResponse { let userInfo: UserInfo? }
struct RememberedLoginCredentials { let account: String; let password: String; let lastLiceseId: String }
enum AccountLoginError: Error { case businessFailure(Int, String) }
enum IMUserAuthenticationState: Equatable { case idle, ready, reconnecting, failed(String) }
@MainActor final class IMUserAuthenticationService {
    static let shared = IMUserAuthenticationService()
    @Published var state: IMUserAuthenticationState = .idle
}
@MainActor final class UserSessionStore {
    static let shared = UserSessionStore()
    var currentUser: UserInfo?
}
@MainActor final class RememberedLoginStore {
    static let shared = RememberedLoginStore()
    func load(lastLiceseId: String) throws -> RememberedLoginCredentials? { nil }
    func save(_ value: RememberedLoginCredentials) throws {}
    func clear() throws {}
}
@MainActor final class OSSNavigationStore {
    static let shared = OSSNavigationStore()
    func lastUsableLiceseId() -> String? { "fixture-club" }
    func clearLastUsableEntry() throws {}
}
@MainActor final class IMConnectionCoordinator {
    static let shared = IMConnectionCoordinator()
    func startCachedReconnect() {}
    func reset() {}
}
@MainActor final class OSSConnectionBootstrap {
    static let shared = OSSConnectionBootstrap()
    func clearCurrent() {}
}
@MainActor enum AppSessionRouter { static func enterMain() {} }
enum ShowAppPageType { case invitationCode }
@MainActor final class RouterTool {
    static let shared = RouterTool()
    var showAppPage = ShowAppPageType.invitationCode
}
@MainActor final class ConsentLoginService: AccountLoginServicing {
    static let shared = ConsentLoginService()
    var requests = 0
    func login(account: String, password: String, progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> AccountLoginResponse {
        requests += 1
        return AccountLoginResponse(userInfo: UserInfo(userUID: "fixture-user"))
    }
}
@MainActor final class ConsentSessionService: LoginSessionServicing {
    static let shared = ConsentSessionService()
    var completions = 0
    func completeLogin(_ response: AccountLoginResponse, account: String, progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws { completions += 1 }
    func cancelPendingLogin() {}
    func clearSession() throws {}
}
typealias AccountLoginService = ConsentLoginService
typealias LoginSessionService = ConsentSessionService

@main struct LoginConsentChecks {
    @MainActor static func main() async {
        do {
            let login = ConsentLoginService()
            let session = ConsentSessionService()
            var routes = 0
            let model = LoginViewModel(loginService: login, sessionService: session, onLoginSucceeded: { routes += 1 })
            try require(!model.hasAcceptedLegalDocuments, "Consent must default to unchecked")
            model.login(account: "", password: "")
            await drain()
            try require(login.requests == 0 && session.completions == 0 && routes == 0,
                        "Unchecked consent must not send login, create session or navigate")
            try require(model.loginPhase == .idle, "Missing consent must keep login idle and prompt with a dialog")
            try require(model.showsLegalConsentAlert && !model.hasAcceptedLegalDocuments,
                        "Missing consent must show a dialog without auto-accepting")
            model.showsLegalConsentAlert = false
            model.hasAcceptedLegalDocuments = true
            model.hasAcceptedLegalDocuments = false
            model.login(account: "fixture-account", password: "fixture-password")
            await drain()
            try require(login.requests == 0 && model.showsLegalConsentAlert, "Unchecking consent must block login and show the dialog again")
            model.hasAcceptedLegalDocuments = true
            model.login(account: "fixture-account", password: "fixture-password")
            await drain()
            try require(login.requests == 1 && session.completions == 1 && routes == 1 && model.loginPhase == .succeeded && !model.showsLegalConsentAlert,
                        "Accepted consent must preserve login, session and navigation flow")
            model.changeClub()
            try require(!model.hasAcceptedLegalDocuments, "Changing club must reset consent")
            let next = LoginViewModel(loginService: login, sessionService: session, onLoginSucceeded: {})
            try require(!next.hasAcceptedLegalDocuments, "New login page must not inherit consent")
            print("PASS: unchecked/revoked consent blocks requests; checked consent logs in; new page and changed club reset consent")
        } catch { print("FAIL: \(error)"); exit(1) }
    }
    @MainActor static func drain() async {
        for _ in 0..<20 { await Task.yield() }
    }
    static func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
        if !value() { throw NSError(domain: "ConsentChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
}

@MainActor enum LoginSecurityNoticeStore { static let shared = Notice(); final class Notice { func clear() {} } }
@MainActor enum LoginSecurityCoordinator { static let shared = Security(); final class Security { func prepareManualLoginPassword(_ password: String, userUID: String, lastLiceseId: String) {} } }
