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
    static var curfewCallbacks: [@MainActor (Int, String) -> Void] = []
    func checkCurfew(onFailure: @escaping @MainActor (Int, String) -> Void) {
        Self.curfewCallbacks.append(onFailure)
    }
    static var logoutCalls: [(String, String)] = []
    static var logoutDelay: UInt64 = 0
    static var holdLogout = false
    static var heldLogout: CheckedContinuation<Void, Never>?
    func logout(userUID: String, token: String) async {
        Self.logoutCalls.append((userUID, token))
        if Self.holdLogout {
            await withCheckedContinuation { Self.heldLogout = $0 }
        } else {
            try? await Task.sleep(nanoseconds: Self.logoutDelay)
        }
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
        expect(CallCoordinator.shared.userUID == "user" && CallCoordinator.shared.sessionID == service.maintenanceSessionID,
               "全局来电监听绑定同一AUTH轮次")
        expect(service.contactBusiness.identity == "user" && service.groups.identity == "user", "通讯录和群绑定同一登录身份")
        SDKSessionMaintenanceClient.logoutCalls = []
        SDKSessionMaintenanceClient.logoutDelay = 30_000_000
        let firstLogout = Task { try await service.signOut() }
        let secondLogout = Task { try await service.signOut() }
        try await firstLogout.value; try await secondLogout.value
        expect(ChatRuntime.shared.userUID == nil && service.contactBusiness.identity == nil && service.groups.identity == nil,
               "退出同时撤销聊天、关系与群管理资格")
        expect(CallCoordinator.shared.userUID == nil && CallConfigurationStore.shared.clearCount > 0,
               "退出关闭通话并清理临时配置")
        expect(SDKSessionMaintenanceClient.logoutCalls.count == 1, "并发退出只发一次服务端请求")
        expect(SDKSessionMaintenanceClient.logoutCalls.first?.0 == "user"
               && SDKSessionMaintenanceClient.logoutCalls.first?.1 == "fixture", "退出请求使用当时的 UID 与 Token")
        expect(store.currentUser == nil && store.cached == nil && !auth.isAuthenticated, "服务端退出后清理本地会话")
        try reset(); seed(); _ = try await service.restoreCachedSession(lastLiceseId: "club")
        let oldCurfewReply = SDKSessionMaintenanceClient.curfewCallbacks.last!
        SDKSessionMaintenanceClient.holdLogout = true
        let delayedLogout = Task { try await service.signOut() }
        let deadline = ContinuousClock.now + .seconds(2)
        while SDKSessionMaintenanceClient.heldLogout == nil {
            guard ContinuousClock.now < deadline else { fatalError("等待旧账号退出请求超时") }
            await Task.yield()
        }
        oldCurfewReply(96305, "旧账号提示")
        expect(service.curfewMessage == nil, "退出中的账号不再展示宵禁提示")
        auth.onSessionInvalidated?(UserSessionError.authenticationRejected(code: 11, message: ""))
        seed(uid: "new", credentialUID: "new")
        _ = try await service.restoreCachedSession(lastLiceseId: "club")
        let newCurfewReply = SDKSessionMaintenanceClient.curfewCallbacks.last!
        newCurfewReply(96305, "新账号提示")
        expect(service.curfewMessage == "新账号提示", "旧退出请求在途时仍展示新登录账号的宵禁提示")
        oldCurfewReply(96305, "迟到的旧账号提示")
        expect(service.curfewMessage == "新账号提示", "旧回包不能覆盖新账号提示")
        SDKSessionMaintenanceClient.heldLogout?.resume()
        SDKSessionMaintenanceClient.heldLogout = nil
        SDKSessionMaintenanceClient.holdLogout = false
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
        SDKSessionMaintenanceClient.curfewCallbacks = []
        auth.resultError = UserSessionError.authenticationTimedOut
        seed()
        _ = try await AppStartupCoordinator.restoreLocalEntry()
        expect(SDKSessionMaintenanceClient.curfewCallbacks.isEmpty, "AUTH 失败不检查宵禁")
        try reset()
        let response = AccountLoginResponse(userInfo: UserInfo(userUID: "user"))
        try await service.completeLogin(response, account: "user") { _ in }
        expect(SDKSessionMaintenanceClient.curfewCallbacks.count == 1, "手动登录与注册共用的成功入口发一次检查")
        let reply = SDKSessionMaintenanceClient.curfewCallbacks[0]
        reply(500, "其他错误")
        reply(96305, "  ")
        expect(service.curfewMessage == nil, "其他错误及空消息保持静默")
        store.currentUser = UserInfo(userUID: "user")
        reply(96305, "提醒原文")
        expect(service.curfewMessage == "提醒原文", "资料刷新后仍显示本轮 96305 原文")
        service.dismissCurfew()
        expect(service.curfewMessage == nil, "确认关闭弹窗")
        reply(96305, "待清理")
        try reset(); seed()
        _ = try await service.restoreCachedSession(lastLiceseId: "club")
        reply(96305, "旧轮次")
        expect(SDKSessionMaintenanceClient.curfewCallbacks.count == 2 && service.curfewMessage == nil,
               "缓存 AUTH 成功发一次检查，同 UID 重登不显示旧回包")
        let loginCurfewText = "当前为宵禁时段，禁止发送消息"
        SDKSessionMaintenanceClient.curfewCallbacks.last!(96305, loginCurfewText)
        expect(service.curfewMessage == loginCurfewText, "登录弹框收到服务端宵禁原文")
        service.dismissCurfew()
        let checksBeforeSendFailure = SDKSessionMaintenanceClient.curfewCallbacks.count
        NotificationCenter.default.post(name: Notification.Name("IMMessagePushRejected"), object: nil,
            userInfo: ["userID": "other", "message": "其他账号"])
        try await Task.sleep(nanoseconds: 20_000_000)
        expect(service.curfewMessage == nil, "其他账号的发送拒绝不弹窗")
        NotificationCenter.default.post(name: Notification.Name("IMMessagePushRejected"), object: nil,
            userInfo: ["userID": "user", "message": loginCurfewText])
        try await Task.sleep(nanoseconds: 20_000_000)
        expect(service.curfewMessage == loginCurfewText, "发送拒绝复用登录宵禁弹框的数据入口和服务端原文")
        service.dismissCurfew()
        NotificationCenter.default.post(name: Notification.Name("IMMessagePushRejected"), object: nil,
            userInfo: ["userID": "user", "message": loginCurfewText])
        try await Task.sleep(nanoseconds: 20_000_000)
        expect(service.curfewMessage == loginCurfewText, "关闭后再次发送被拒绝仍能展示同一条宵禁文案")
        expect(SDKSessionMaintenanceClient.curfewCallbacks.count == checksBeforeSendFailure,
               "与 xgd 一致，发送拒绝采用 pushMsg 原文，不额外查询登录宵禁接口")
        try service.clearSession()
        NotificationCenter.default.post(name: Notification.Name("IMMessagePushRejected"), object: nil,
            userInfo: ["userID": "user", "message": "退出后的通知"])
        try await Task.sleep(nanoseconds: 20_000_000)
        expect(service.curfewMessage == nil, "退出后释放发送拒绝观察并清空提示")
        print("Session restore checks passed")
    }
}
