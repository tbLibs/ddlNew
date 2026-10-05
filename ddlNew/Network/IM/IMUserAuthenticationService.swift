//
//  IMUserAuthenticationService.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Combine
import Foundation
import NoaChatCore

/// 配置 SDK 用户并等待实际 AUTH；认证后的重连和 Token 刷新仍由 SDK 执行。
@MainActor
final class IMUserAuthenticationService: ObservableObject {
    static let shared = IMUserAuthenticationService()

    @Published private(set) var state: IMUserAuthenticationState = .idle

    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }
    private var socket: NoaIMSocketManager { NoaIMSocketManager.sharedTool() }
    private let database = UserDatabaseManager.shared
    private var delegate: IMUserAuthenticationDelegate?
    private var waiter: IMUserAuthenticationWaiter?
    private var generation = UUID()
    private var userUID: String?
    /// 暂时断网不清除会话；只通知账号失效或本地凭据更新失败。
    var onSessionInvalidated: (@MainActor (Error) -> Void)?
    /// 只转发新 Token，持久化交给会话层，不在认证类中处理存储。
    var onTokenRefreshed: (@MainActor (String, String) throws -> Void)?

    private init() {}

    func authenticate(user: UserInfo, credentials: UserSessionCredentials,
                      progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws {
        try Task<Never, Never>.checkCancellation()
        guard user.userUID == credentials.userUID, credentials.isValid,
              socket.currentSocketConnectStatus(), socket.isExchangeEcdhKeySuccess() else {
            throw AccountLoginError.connectionNotReady
        }
        guard delegate == nil else { throw AccountLoginError.connectionChanged }
        generation = UUID()
        let runID = generation
        userUID = user.userUID
        let waiting = IMUserAuthenticationWaiter()
        waiter = waiting
        state = .authenticating
        installDelegate(runID: runID)

        // 先监听，再配置 SDK；SDK 首次配置用户会同步建库，并自动触发一次 AUTH。
        try await waiting.run {
            progress(.configuringSDK)
            self.sdk.clearMyUserInfo()
            self.sdk.configSDKDeviceSecret(credentials.deviceSecret)
            let options = NoaIMSDKUserOptions()
            options.userID = user.userUID
            options.userToken = credentials.token
            options.userNickname = user.nickname
            options.userAvatar = user.avatar
            self.sdk.configSDKUser(with: options)
            do {
                try self.database.requireReady(for: user.userUID)
                debugPrint("[用户数据库] 初始化成功，用户：\(user.userUID)")
                progress(.authenticating)
            } catch {
                waiting.finish(.failure(error))
            }
        }
        try Task<Never, Never>.checkCancellation()
        guard generation == runID, isAuthenticated else { throw AccountLoginError.connectionChanged }
        waiter = nil
        state = .ready
        debugPrint("[用户认证] TCP AUTH 成功，用户：\(user.userUID)")
    }

    /// 必须核对 Socket 的 AUTH 标志，不能以 ECDH 或心跳成功代替用户认证。
    var isAuthenticated: Bool {
        userUID != nil && sdk.myUserID() == userUID
            && sdk.isUserAuthenticated()
    }

    func reset() {
        generation = UUID()
        if let delegate {
            sdk.removeUserDelegate(delegate)
            sdk.removeConnectDelegate(delegate)
        }
        delegate = nil
        waiter?.finish(.failure(CancellationError()))
        waiter = nil
        userUID = nil
        onSessionInvalidated = nil
        onTokenRefreshed = nil
        socket.clearUserInfo()
        socket.prepareForConnectionInitialization()
        sdk.clearMyUserInfo()
        database.close()
        state = .idle
    }

    /// 清理后保留错误提示，不能继续显示已认证。
    func markFailed(_ message: String) {
        state = .failed(message)
    }

    private func installDelegate(runID: UUID) {
        let delegate = IMUserAuthenticationDelegate(
            authenticated: { [weak self] in self?.didAuthenticate(runID: runID) },
            disconnected: { [weak self] in
                guard let self, self.generation == runID, !self.isAuthenticated else { return }
                if self.state == .ready { self.state = .reconnecting }
            },
            rejected: { [weak self] code, message in
                self?.fail(UserSessionError.authenticationRejected(code: code, message: message), runID: runID)
            },
            tokenRefreshed: { [weak self] token in
                guard let self, self.generation == runID, let userUID = self.userUID,
                      self.sdk.myUserID() == userUID, self.sdk.myUserToken() == token else { return }
                do { try self.onTokenRefreshed?(token, userUID) }
                catch { self.fail(error, runID: runID) }
            },
            httpNodeUpdated: { [weak self] httpNode in
                guard let self, self.generation == runID, self.userUID != nil else { return }
                OSSConnectionBootstrap.shared.updateHTTPHost(httpNode)
            }
        )
        self.delegate = delegate
        sdk.addUserDelegate(delegate)
        sdk.addConnectDelegate(delegate)
    }

    private func didAuthenticate(runID: UUID) {
        guard generation == runID, isAuthenticated else { return }
        state = .ready
        waiter?.finish(.success(()))
    }

    private func fail(_ error: Error, runID: UUID) {
        guard generation == runID else { return }
        state = .failed(error.localizedDescription)
        if let waiter {
            waiter.finish(.failure(error))
        } else {
            onSessionInvalidated?(error)
        }
    }
}
