import Foundation

// 用替身隔离 Keychain、SDK 和导航请求，执行真实会话编排与启动路由。
struct UserInfo { let userUID: String }
struct UserSessionCredentials {
    let userUID: String
    let token: String
    let lastLiceseId: String
    var isValid: Bool { !userUID.isEmpty && !token.isEmpty && !lastLiceseId.isEmpty }
}
struct AccountLoginResponse { let userInfo: UserInfo? }
enum AccountLoginError: Error { case connectionNotReady, connectionChanged }
enum ShowAppPageType: Equatable { case login, tabbar, invitationCode }
struct Plan { let apiHost = URL(string: "https://example.invalid")!; let tcpCandidates = [1] }

@MainActor final class UserSessionStore {
    static let shared = UserSessionStore()
    var cached: (user: UserInfo, credentials: UserSessionCredentials)?
    var currentUser: UserInfo?
    var clearCount = 0
    var loadError: Error?
    func loadCachedSession(lastLiceseId: String) throws -> (user: UserInfo, credentials: UserSessionCredentials)? {
        if let loadError { throw loadError }
        return cached
    }
    func activateCachedUser(_ user: UserInfo) { currentUser = user }
    func revokeCurrentUser() { currentUser = nil }
    func save(_ response: AccountLoginResponse, account: String, lastLiceseId: String) throws -> UserSessionCredentials {
        currentUser = response.userInfo
        return UserSessionCredentials(userUID: response.userInfo!.userUID, token: "fixture", lastLiceseId: lastLiceseId)
    }
    func updateToken(_ token: String, userUID: String) throws {
        guard currentUser?.userUID == userUID, let cached else { throw UserSessionError.invalidData }
        self.cached = (cached.user, .init(userUID: userUID, token: token, lastLiceseId: cached.credentials.lastLiceseId))
    }
    func clear() throws { clearCount += 1; cached = nil; currentUser = nil }
}

@MainActor final class IMUserAuthenticationService {
    static let shared = IMUserAuthenticationService()
    var onSessionInvalidated: (@MainActor (Error) -> Void)?
    var onTokenRefreshed: (@MainActor (String, String) throws -> Void)?
    var resultError: Error?
    var authenticateCount = 0
    var refreshedToken: String?
    var didAuthenticate: (() -> Void)?
    var isAuthenticated = false
    func authenticate(user: UserInfo, credentials: UserSessionCredentials,
                      progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws {
        authenticateCount += 1
        progress(.authenticating)
        if let refreshedToken { try onTokenRefreshed?(refreshedToken, user.userUID) }
        didAuthenticate?()
        if let resultError { throw resultError }
        isAuthenticated = true
    }
    func reset() { onSessionInvalidated = nil; onTokenRefreshed = nil; isAuthenticated = false }
    func markFailed(_ message: String) {}
}

@MainActor final class IMConnectionCoordinator {
    static let shared = IMConnectionCoordinator()
    var loginConnectionID: UUID? = UUID()
    var owns = false
    var readinessError: Error?
    var reconnectCount = 0
    func beginUserAuthentication(connectionID: UUID) throws {
        guard loginConnectionID == connectionID else { throw AccountLoginError.connectionChanged }
        owns = true
    }
    func isUserConnectionCurrent(_ id: UUID) -> Bool { owns && loginConnectionID == id }
    func releaseUserConnection(reconnect: Bool) { owns = false; if reconnect { reconnectCount += 1 } }
    func startCachedReconnect() { reconnectCount += 1 }
    func waitForLoginReadiness() async throws { if let readinessError { throw readinessError } }
    func reset() { owns = false }
}
@MainActor final class OSSNavigationStore {
    static let shared = OSSNavigationStore()
    var license: String? = "club"
    func lastUsableLiceseId() -> String? { license }
}
@MainActor final class OSSConnectionBootstrap {
    static let shared = OSSConnectionBootstrap()
    func clearCurrent() {}
    func prepare(requireFresh: Bool) throws -> Plan { Plan() }
}
@MainActor final class SystemConfigStore {
    static let shared = SystemConfigStore()
    func load(apiHost: URL) -> Int? { 1 }
}

@main struct Checks {
    @MainActor static func main() async throws {
        let service = LoginSessionService.shared
        let store = UserSessionStore.shared
        let auth = IMUserAuthenticationService.shared
        let connection = IMConnectionCoordinator.shared
        func reset() throws {
            try service.clearSession()
            store.clearCount = 0; store.loadError = nil
            auth.authenticateCount = 0; auth.resultError = nil; auth.refreshedToken = nil; auth.didAuthenticate = nil
            connection.loginConnectionID = UUID(); connection.readinessError = nil; connection.reconnectCount = 0
            OSSNavigationStore.shared.license = "club"
        }
        func seed(uid: String = "user", credentialUID: String = "user", token: String = "fixture", club: String = "club") {
            store.cached = (UserInfo(userUID: uid), UserSessionCredentials(userUID: credentialUID, token: token, lastLiceseId: club))
        }
        func expect(_ value: Bool, _ name: String) {
            guard value else { fatalError("FAIL: \(name)") }
            print("PASS: \(name)")
        }
        try reset()
        expect(try await service.restoreCachedSession(lastLiceseId: "club") == false, "无缓存不进行 AUTH")
        expect(auth.authenticateCount == 0, "无缓存保留登录入口")

        for fixture in [("other", "user", "fixture", "club"), ("user", "user", "", "club"), ("user", "user", "fixture", "other")] {
            try reset(); seed(uid: fixture.0, credentialUID: fixture.1, token: fixture.2, club: fixture.3)
            do { _ = try await service.restoreCachedSession(lastLiceseId: "club"); fatalError("应拒绝不匹配缓存") }
            catch { expect(auth.authenticateCount == 0 && store.cached == nil, "不匹配的用户、Token 或俱乐部不能恢复") }
        }
        try reset(); seed(); auth.refreshedToken = "refreshed"
        expect(try await AppStartupCoordinator.restoreLocalEntry() == .tabbar, "缓存会话完成真实 AUTH 后进入主页")
        expect(store.currentUser?.userUID == "user" && store.cached?.credentials.token == "refreshed", "AUTH 期间刷新 Token 正确持久化")

        try reset(); seed(); auth.resultError = UserSessionError.authenticationRejected(code: 403, message: "已失效")
        expect(try await AppStartupCoordinator.restoreLocalEntry() == .login, "认证失效返回登录页")
        expect(store.cached == nil && store.currentUser == nil, "被拒绝的会话清除缓存")

        try reset(); seed(); auth.resultError = UserSessionError.authenticationTimedOut
        expect(try await AppStartupCoordinator.restoreLocalEntry() == .login, "AUTH 暂时超时允许手动登录")
        expect(store.cached != nil && store.currentUser == nil && !connection.owns, "暂时超时保留持久凭据并释放用户连接")

        try reset(); seed(); connection.readinessError = AccountLoginError.connectionNotReady
        expect(try await AppStartupCoordinator.restoreLocalEntry() == .invitationCode, "启动连接失败仍返回邀请码")
        expect(store.cached != nil && auth.authenticateCount == 0, "连接失败不能删除缓存或发起 AUTH")

        try reset(); seed(); auth.resultError = CancellationError()
        do { _ = try await service.restoreCachedSession(lastLiceseId: "club"); fatalError("应传播取消") }
        catch is CancellationError { expect(store.cached != nil && store.currentUser == nil, "取消恢复不发布用户也不删除凭据") }

        try reset(); seed(); auth.didAuthenticate = { connection.loginConnectionID = UUID() }
        do { _ = try await service.restoreCachedSession(lastLiceseId: "club"); fatalError("旧连接不能成功") }
        catch { expect(store.currentUser == nil && !connection.owns, "认证后连接被替换不能发布旧会话") }

        try reset(); seed(); _ = try await service.restoreCachedSession(lastLiceseId: "club")
        let oldTokenCallback = auth.onTokenRefreshed
        auth.onSessionInvalidated?(UserSessionError.authenticationRejected(code: 403, message: "已失效"))
        expect(store.cached == nil && store.currentUser == nil && !connection.owns, "恢复后强制下线沿用真实登录清理流程")

        try reset(); seed(); _ = try await service.restoreCachedSession(lastLiceseId: "club")
        try oldTokenCallback?("late-token", "user")
        expect(store.cached?.credentials.token == "fixture", "旧会话迟到的 Token 刷新不能覆盖新会话")

        try reset(); seed(); store.loadError = UserSessionError.keychainFailure(-1)
        expect(try await AppStartupCoordinator.restoreLocalEntry() == .login, "凭据暂不可读时允许手动登录")
        expect(store.cached != nil && auth.authenticateCount == 0, "Keychain 暂不可读不删持久缓存")

        try reset(); seed(); _ = try await service.restoreCachedSession(lastLiceseId: "club")
        service.cancelStartupRestoration()
        expect(store.cached != nil && store.currentUser == nil && !connection.owns, "AUTH 成功后启动取消仍释放运行时会话")
        expect(try await service.restoreCachedSession(lastLiceseId: "club"), "取消窗口结束后可再次恢复")
        service.finishStartupRestoration()
        service.cancelStartupRestoration()
        expect(store.currentUser != nil && connection.owns, "路由已接受的会话不受旧启动取消影响")

        try reset(); OSSNavigationStore.shared.license = nil
        expect(try await AppStartupCoordinator.restoreLocalEntry() == .invitationCode, "没有邀请码不能根据缓存绕过入口")
        print("Session restore checks passed")
    }
}
