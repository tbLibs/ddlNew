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
struct UserSessionSnapshot { let user: UserInfo; let credentials: UserSessionCredentials }
@MainActor final class SessionMaintenanceCoordinator {
    static let shared = SessionMaintenanceCoordinator()
    var startCount = 0
    var stopCount = 0
    func start(userUID: String, lastLiceseId: String) { startCount += 1 }
    func stop() { stopCount += 1 }
}
@MainActor final class LoginSecurityCoordinator {
    static let shared = LoginSecurityCoordinator()
    var startCount = 0
    func start(userUID: String, lastLiceseId: String) { startCount += 1 }
    func stop(clearCachedRequirement: Bool = false) {}
}
@MainActor final class LoginSecurityNoticeStore {
    static let shared = LoginSecurityNoticeStore()
    var message: String?
    func record(message: String) { self.message = message }
}
@MainActor final class SDKSessionMaintenanceClient {
    static var logoutCalls: [(String, String)] = []
    static var logoutDelay: UInt64 = 0
    func logout(userUID: String, token: String) async {
        Self.logoutCalls.append((userUID, token))
        try? await Task.sleep(nanoseconds: Self.logoutDelay)
    }
}
enum AccountLoginError: Error { case connectionNotReady, connectionChanged }
enum ShowAppPageType: Equatable { case login, tabbar, invitationCode }
struct Plan { let lastLiceseId = "fixture-license"; let apiHost = URL(string: "https://example.invalid")!; let tcpCandidates = [1] }
struct SDKContactsClient {}
struct SDKConversationsClient {}
// 合并后真实通讯录和消息会话共用登录生命周期，替身记录订阅、读库和清理顺序。
@MainActor final class ContactsStore {
    var prepareCount = 0
    var reloadCount = 0
    var resetCount = 0
    init(client: SDKContactsClient) {}
    func prepare(for userUID: String) { prepareCount += 1 }
    func reload() async { reloadCount += 1 }
    func reset() { resetCount += 1 }
}
@MainActor final class ConversationsStore {
    var prepareCount = 0
    var reloadCount = 0
    var resetCount = 0
    init(client: SDKConversationsClient) {}
    func prepare(for userUID: String) { prepareCount += 1 }
    func reload() async { reloadCount += 1 }
    func reset() { resetCount += 1 }
}

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
    func cachedSession() throws -> UserSessionSnapshot? {
        guard let cached else { return nil }
        return UserSessionSnapshot(user: cached.user, credentials: cached.credentials)
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
    func load(apiHost: URL?, lastLiceseId: String? = nil) -> Int? { 1 }
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
        expect(service.contacts.prepareCount > 0 && service.contacts.reloadCount > 0
               && service.conversations.prepareCount > 0 && service.conversations.reloadCount > 0,
               "恢复登录沿用真实通讯录和消息的订阅与认证后读库")

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
        try reset(); seed(); _ = try await service.restoreCachedSession(lastLiceseId: "club")
        expect(SessionMaintenanceCoordinator.shared.startCount > 0 && LoginSecurityCoordinator.shared.startCount > 0,
               "真实 AUTH 后启动维护和安全检查")
        expect(ChatRuntime.shared.userUID == "user" && ChatRuntime.shared.sessionID == service.maintenanceSessionID,
               "聊天资格绑定AUTH成功的具体登录轮次")
        expect(service.contactBusiness.identity == "user" && service.groups.identity == "user", "通讯录和群绑定同一登录身份")
        SDKSessionMaintenanceClient.logoutCalls = []
        SDKSessionMaintenanceClient.logoutDelay = 30_000_000
        let firstLogout = Task { try await service.signOut() }
        let secondLogout = Task { try await service.signOut() }
        try await firstLogout.value; try await secondLogout.value
        expect(ChatRuntime.shared.userUID == nil && service.contactBusiness.identity == nil && service.groups.identity == nil,
               "退出同时撤销聊天、关系与群管理资格")
        expect(SDKSessionMaintenanceClient.logoutCalls.count == 1, "并发退出只发一次服务端请求")
        expect(SDKSessionMaintenanceClient.logoutCalls.first?.0 == "user"
               && SDKSessionMaintenanceClient.logoutCalls.first?.1 == "fixture", "退出请求使用当时的 UID 与 Token")
        expect(store.currentUser == nil && store.cached == nil && !auth.isAuthenticated, "服务端退出后清理本地会话")
        try reset(); seed(); _ = try await service.restoreCachedSession(lastLiceseId: "club")
        let delayedLogout = Task { try await service.signOut() }
        try await Task.sleep(nanoseconds: 5_000_000)
        auth.onSessionInvalidated?(UserSessionError.authenticationRejected(code: 11, message: ""))
        seed(uid: "new", credentialUID: "new")
        _ = try await service.restoreCachedSession(lastLiceseId: "club")
        try await delayedLogout.value
        expect(store.currentUser?.userUID == "new" && auth.isAuthenticated, "旧退出请求返回不清理新账号")
        expect(LoginSecurityNoticeStore.shared.message?.contains("设备") == true, "强制下线保留具体原因")
        try reset()
        SDKSessionMaintenanceClient.logoutCalls = []
        try await service.signOut()
        expect(SDKSessionMaintenanceClient.logoutCalls.isEmpty, "访客退出不发送用户退出请求")
        try reset(); seed(); _ = try await service.restoreCachedSession(lastLiceseId: "club")
        let previousMaintenanceSession = service.maintenanceSessionID!
        service.handleMaintenanceRejection(code: 40029, message: "", userUID: "user", lastLiceseId: "club",
                                           sessionID: previousMaintenanceSession)
        expect(store.currentUser == nil && store.cached == nil, "维护接口明确设备封禁撤销当前会话")
        seed(); _ = try await service.restoreCachedSession(lastLiceseId: "club")
        service.handleMaintenanceRejection(code: 40015, message: "", userUID: "user", lastLiceseId: "club",
                                           sessionID: previousMaintenanceSession)
        expect(store.currentUser?.userUID == "user" && auth.isAuthenticated, "同UID重登后旧维护封禁回调不能清理新会话")
        service.handleMaintenanceRejection(code: 0, message: "timeout", userUID: "user", lastLiceseId: "club",
                                           sessionID: service.maintenanceSessionID!)
        expect(auth.isAuthenticated, "维护请求临时失败不撤销会话")
        try reset()
        print("Session restore checks passed")
    }
}
