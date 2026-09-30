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
    private var sessionID: UUID?
    private var pendingID: UUID?

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

    /// 重启只使用用户资料、token 和设备凭据，不调用账号密码登录或读取记住的密码。
    func restoreCachedSession() async throws -> Bool {
        try Task<Never, Never>.checkCancellation()
        guard let lastLiceseId = OSSNavigationStore.shared.lastUsableLiceseId() else { return false }
        let snapshot: UserSessionSnapshot
        do {
            guard let cached = try store.cachedSession() else { return false }
            snapshot = cached
        } catch {
            if (error as? UserSessionError)?.invalidatesCachedSession == true {
                try store.clear()
            }
            throw error
        }
        // 导航只有一份，但账号凭据仍属于原俱乐部，不能拿去认证其他俱乐部。
        guard snapshot.credentials.lastLiceseId == lastLiceseId else {
            try store.clear()
            return false
        }
        guard sessionID == nil, let connectionID = connection.loginConnectionID else {
            throw AccountLoginError.connectionNotReady
        }
        let runID = UUID()
        sessionID = runID
        pendingID = runID
        do {
            try store.restore(snapshot)
            try await authenticate(user: snapshot.user, credentials: snapshot.credentials,
                                   connectionID: connectionID, runID: runID, progress: { _ in })
            debugPrint("[启动会话] 缓存用户 AUTH 成功，进入主页")
            return true
        } catch {
            if sessionID == runID {
                let preserve = (error as? UserSessionError)?.invalidatesCachedSession != true
                invalidateSession(error, preserveCache: preserve)
            }
            throw error
        }
    }

    /// 手动登录和缓存恢复复用同一套 SDK/建库/AUTH 流程，以及 token 更新和下线回调。
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
        try await authentication.authenticate(user: user, credentials: credentials, progress: progress)
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
        authentication.reset()
        connection.releaseUserConnection(reconnect: false)
        try store.clear()
    }

    private func invalidateSession(_ error: Error, preserveCache: Bool = false) {
        sessionID = nil
        pendingID = nil
        authentication.reset()
        if preserveCache {
            store.deactivate()
        } else {
            do { try store.clear() }
            catch { debugPrint("[用户会话] 清理本地会话失败：\(error)") }
            if !(error is CancellationError) { authentication.markFailed(error.localizedDescription) }
        }
        // 恢复可重新领取登录密钥的访客链路，不继续使用残留用户 token。
        // 手动登录取消后仍恢复访客链路；启动恢复被取消则由根启动任务决定是否重连。
        connection.releaseUserConnection(reconnect: !preserveCache || !(error is CancellationError))
    }
}
