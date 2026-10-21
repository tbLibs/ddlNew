//
//  LoginSessionService.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

/// 登录后的编排层：保存 → 交接连接 → SDK 配置/建库 → AUTH；不承担页面跳转。
@MainActor
final class LoginSessionService: LoginSessionServicing {
    static let shared = LoginSessionService()

    private let store = UserSessionStore.shared
    private let authentication = IMUserAuthenticationService.shared
    private let connection = IMConnectionCoordinator.shared
    /// 真实通讯录和会话在 AUTH 前订阅、完成认证后读库，退出时统一清理。
    let contacts = ContactsStore(client: SDKContactsClient())
    let conversations = ConversationsStore(client: SDKConversationsClient())
    /// 关系操作与群列表复用同一登录所有者，权限始终读取当前角色快照。
    let contactBusiness = ContactsBusinessStore.shared
    let groups = GroupsStore.shared
    let globalSearch = GlobalSearchStore(client: SDKGlobalSearchClient())
    private var sessionID: UUID?
    private var pendingID: UUID?
    /// 启动 AUTH 已成功但根页面尚未接收结果时，仍需允许取消并释放运行时会话。
    private var startupRestoreID: UUID?
    private var signOutTask: Task<Void, Error>?

    /// 保持单一认证编排所有者，页面不能创建第二套 SDK 会话。
    private init() {}

    /// 维护回调使用会话轮次，同 UID 退出后重新登录也属于另一轮身份。
    var maintenanceSessionID: UUID? { sessionID }

    /// 只有当前用户、邀请码和会话轮次的明确拒绝才撤销身份。
    func handleMaintenanceRejection(code: Int, message: String, userUID: String,
                                    lastLiceseId: String, sessionID: UUID) {
        guard self.sessionID == sessionID, store.currentUser?.userUID == userUID,
              OSSNavigationStore.shared.lastUsableLiceseId() == lastLiceseId,
              [40015, 40029, 40030, 90018, 900017].contains(code) else { return }
        invalidateSession(UserSessionError.authenticationRejected(code: code, message: message))
    }

    /// 保存真实凭据后执行统一 AUTH，并在失败时释放这一轮身份。
    func completeLogin(_ response: AccountLoginResponse, account: String,
                       progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws {
        try Task<Never, Never>.checkCancellation()
        guard sessionID == nil, let connectionID = connection.loginConnectionID,
              let lastLiceseId = OSSNavigationStore.shared.lastUsableLiceseId(),
              let user = response.userInfo else { throw AccountLoginError.connectionNotReady }
        let runID = UUID()
        sessionID = runID
        pendingID = runID
        do {
            progress(.savingSession)
            let credentials = try store.save(response, account: account.trimmingCharacters(in: .whitespacesAndNewlines),
                                             lastLiceseId: lastLiceseId)
            try await authenticate(user: user, credentials: credentials, connectionID: connectionID,
                                   runID: runID, progress: progress)
            debugPrint("[用户会话] 保存、SDK 用户配置、数据库与 TCP AUTH 全部完成")
        } catch {
            // 旧轮次结束时不能清理已经启动的新会话。
            if sessionID == runID { invalidateSession(error) }
            throw error
        }
    }

    /// 使用已有 Token 恢复，不重放密码登录；SDK 负责过期 Token 的刷新与认证。
    func restoreCachedSession(lastLiceseId: String,
                              progress: @escaping @MainActor (AccountLoginPhase) -> Void = { _ in }) async throws -> Bool {
        try Task<Never, Never>.checkCancellation()
        guard sessionID == nil, let connectionID = connection.loginConnectionID else {
            throw AccountLoginError.connectionNotReady
        }
        let cached: (user: UserInfo, credentials: UserSessionCredentials)
        do {
            guard let value = try store.loadCachedSession(lastLiceseId: lastLiceseId) else { return false }
            guard value.credentials.isValid, value.credentials.userUID == value.user.userUID,
                  value.credentials.lastLiceseId == lastLiceseId else { throw UserSessionError.invalidData }
            cached = value
        } catch {
            // 缓存结构损坏应清理；Keychain 暂时不可读时保留，允许用户稍后重试。
            if case UserSessionError.invalidData = error { try? store.clear() }
            throw error
        }
        let runID = UUID()
        sessionID = runID
        pendingID = runID
        startupRestoreID = runID
        store.activateCachedUser(cached.user)
        do {
            try await authenticate(user: cached.user, credentials: cached.credentials,
                                   connectionID: connectionID, runID: runID, progress: progress)
            debugPrint("[启动恢复] 缓存会话已通过 TCP 用户认证")
            return true
        } catch {
            if sessionID == runID {
                // 明确认证拒绝才删除凭据；网络超时、断线和取消均不等于账号失效。
                let clearStoredSession: Bool
                switch error {
                case UserSessionError.authenticationRejected, UserSessionError.invalidData:
                    clearStoredSession = true
                default:
                    clearStoredSession = false
                }
                invalidateSession(error, clearStoredSession: clearStoredSession,
                                  reconnect: !(error is CancellationError))
            }
            throw error
        }
    }

    /// 根页面接收启动结果后交出取消权限，后续页面变化不能注销正常会话。
    func finishStartupRestoration() {
        startupRestoreID = nil
    }

    /// 处理 AUTH 成功与启动路由接收之间的取消窗口，保留磁盘凭据供下次恢复。
    func cancelStartupRestoration() {
        guard let id = startupRestoreID, sessionID == id else { return }
        invalidateSession(CancellationError(), clearStoredSession: false, reconnect: false)
    }

    /// 手动登录、注册和缓存恢复共用同一连接交接、建库、AUTH 与失效监听。
    private func authenticate(user: UserInfo, credentials: UserSessionCredentials,
                              connectionID: UUID, runID: UUID,
                              progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws {
        try connection.beginUserAuthentication(connectionID: connectionID)
        authentication.onSessionInvalidated = { [weak self] error in
            guard let self, self.sessionID == runID else { return }
            self.invalidateSession(error)
        }
        authentication.onTokenRefreshed = { [weak self] token, userUID in
            guard let self, self.sessionID == runID else { return }
            try self.store.updateToken(token, userUID: userUID)
        }
        // AUTH 后 SDK 会自动同步好友和会话；提前订阅，避免首轮回调在页面创建前丢失。
        contacts.prepare(for: user.userUID)
        conversations.prepare(for: user.userUID)
        contactBusiness.prepare(userUID: user.userUID, license: credentials.lastLiceseId)
        groups.prepare(userUID: user.userUID, license: credentials.lastLiceseId)
        globalSearch.prepare(userUID: user.userUID)
        try await authentication.authenticate(user: user, credentials: credentials, progress: progress)
        try Task<Never, Never>.checkCancellation()
        guard sessionID == runID, connection.isUserConnectionCurrent(connectionID),
              authentication.isAuthenticated, store.currentUser?.userUID == user.userUID else {
            throw AccountLoginError.connectionChanged
        }
        // AUTH 成功即监听来电，联系人/会话缓存的异步读取不能留下漏接窗口。
        CallCoordinator.shared.activate(userUID: user.userUID, tenantID: credentials.lastLiceseId, sessionID: runID)
        // 认证和用户建库完成后再读缓存，SDK 后续同步回调会触发增量重读。
        await contacts.reload()
        await conversations.reload()
        // 缓存读取已经改为异步，返回后必须再次确认没有退出或切换到新会话。
        try Task<Never, Never>.checkCancellation()
        guard sessionID == runID, connection.isUserConnectionCurrent(connectionID),
              authentication.isAuthenticated, store.currentUser?.userUID == user.userUID else {
            throw AccountLoginError.connectionChanged
        }
        pendingID = nil
        ChatRuntime.shared.activate(userUID: user.userUID, tenantID: credentials.lastLiceseId, sessionID: runID)
        // 业务 HTTP 列表不能阻塞登录；已有会话轮次在完成后再次核验，退出时 Store 会失效。
        Task { [weak self] in
            guard let self, self.sessionID == runID else { return }
            await self.contactBusiness.reload()
            guard self.sessionID == runID else { return }
            await self.groups.reload()
        }
        SessionMaintenanceCoordinator.shared.start(userUID: user.userUID, lastLiceseId: credentials.lastLiceseId)
        LoginSecurityCoordinator.shared.start(userUID: user.userUID, lastLiceseId: credentials.lastLiceseId)
    }

    /// 只取消尚未交付页面的手动登录，不影响运行中的正常会话。
    func cancelPendingLogin() {
        guard pendingID != nil else { return }
        invalidateSession(CancellationError())
    }

    /// 用户主动退出时先发送当前 UID/Token；不阻塞本地退出，也不让迟到结果清理新会话。
    func signOut() async throws {
        if let existing = signOutTask { return try await existing.value }
        let run = sessionID
        let task = Task { @MainActor [self] in
            SessionMaintenanceCoordinator.shared.stop()
            if authentication.isAuthenticated, let snapshot = try? store.cachedSession() {
                await SDKSessionMaintenanceClient().logout(userUID: snapshot.credentials.userUID,
                                                           token: snapshot.credentials.token)
            }
            guard sessionID == run else { return }
            try clearSession()
        }
        signOutTask = task
        defer { signOutTask = nil }
        try await task.value
    }

    /// 撤销全部业务资格后再关闭数据库及清理本地凭据。
    func clearSession() throws {
        sessionID = nil
        pendingID = nil
        startupRestoreID = nil
        SessionMaintenanceCoordinator.shared.stop()
        LoginSecurityCoordinator.shared.stop(clearCachedRequirement: true)
        contacts.reset()
        conversations.reset()
        contactBusiness.reset()
        groups.reset()
        globalSearch.reset()
        CallCoordinator.shared.close()
        CallConfigurationStore.shared.clear()
        ChatRuntime.shared.close()
        authentication.reset()
        connection.releaseUserConnection(reconnect: false)
        try store.clear()
    }

    /// 认证失效、恢复失败和取消共用清理，网络失败可保留磁盘恢复凭据。
    private func invalidateSession(_ error: Error, clearStoredSession: Bool = true, reconnect: Bool = true) {
        if case UserSessionError.authenticationRejected = error {
            LoginSecurityNoticeStore.shared.record(message: error.localizedDescription)
        }
        sessionID = nil
        pendingID = nil
        startupRestoreID = nil
        SessionMaintenanceCoordinator.shared.stop()
        LoginSecurityCoordinator.shared.stop(clearCachedRequirement: clearStoredSession)
        contacts.reset()
        conversations.reset()
        contactBusiness.reset()
        groups.reset()
        globalSearch.reset()
        CallCoordinator.shared.close()
        CallConfigurationStore.shared.clear()
        ChatRuntime.shared.close()
        authentication.reset()
        if clearStoredSession {
            do { try store.clear() }
            catch { debugPrint("[用户会话] 清理本地会话失败：\(error)") }
        } else {
            store.revokeCurrentUser()
        }
        if !(error is CancellationError) { authentication.markFailed(error.localizedDescription) }
        // 恢复可重新领取登录密钥的访客链路，不继续使用残留用户 token。
        connection.releaseUserConnection(reconnect: reconnect)
    }
}
