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
    private var sessionID: UUID?
    private var pendingID: UUID?
    /// 启动 AUTH 已成功但根页面尚未接收结果时，仍需允许取消并释放运行时会话。
    private var startupRestoreID: UUID?

    private init() {}

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
        try await authentication.authenticate(user: user, credentials: credentials, progress: progress)
        try Task<Never, Never>.checkCancellation()
        guard sessionID == runID, connection.isUserConnectionCurrent(connectionID),
              authentication.isAuthenticated, store.currentUser?.userUID == user.userUID else {
            throw AccountLoginError.connectionChanged
        }
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
    }

    func cancelPendingLogin() {
        guard pendingID != nil else { return }
        invalidateSession(CancellationError())
    }

    func clearSession() throws {
        sessionID = nil
        pendingID = nil
        startupRestoreID = nil
        contacts.reset()
        conversations.reset()
        authentication.reset()
        connection.releaseUserConnection(reconnect: false)
        try store.clear()
    }

    private func invalidateSession(_ error: Error, clearStoredSession: Bool = true, reconnect: Bool = true) {
        sessionID = nil
        pendingID = nil
        startupRestoreID = nil
        contacts.reset()
        conversations.reset()
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
