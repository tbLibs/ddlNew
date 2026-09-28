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
            guard sessionID == runID, connection.isUserConnectionCurrent(connectionID) else {
                throw AccountLoginError.connectionChanged
            }
            pendingID = nil
            debugPrint("[用户会话] 保存、SDK 用户配置、数据库与 TCP AUTH 全部完成")
        } catch {
            // 旧轮次结束时不能清理已经启动的新会话。
            if sessionID == runID { invalidateSession(error) }
            throw error
        }
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

    private func invalidateSession(_ error: Error) {
        sessionID = nil
        pendingID = nil
        authentication.reset()
        do { try store.clear() }
        catch { debugPrint("[用户会话] 清理本地会话失败：\(error)") }
        if !(error is CancellationError) { authentication.markFailed(error.localizedDescription) }
        // 恢复可重新领取登录密钥的访客链路，不继续使用残留用户 token。
        connection.releaseUserConnection(reconnect: true)
    }
}
