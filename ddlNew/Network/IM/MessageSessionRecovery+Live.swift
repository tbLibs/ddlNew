//
//  MessageSessionRecovery+Live.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//

import Foundation

extension MessageSessionRecovery {
    static let shared: MessageSessionRecovery = MessageSessionRecovery(loadLocalSnapshot: { identity in
        let store = UserSessionStore.shared
        guard store.currentUser?.userUID == identity.userUID,
              OSSNavigationStore.shared.lastUsableLiceseId() == identity.license else { return }
        await LoginSessionService.shared.conversations.loadLocalSnapshot(for: identity.userUID) {
            guard let cached = try store.loadCachedSession(lastLiceseId: identity.license),
                  cached.user.userUID == identity.userUID else { throw UserSessionError.invalidData }
            return try await SDKConversationsClient.loadLocalSnapshot(userUID: identity.userUID,
                                                                      token: cached.credentials.token)
        }
    }, attempt: { identity in
        let connection = IMConnectionCoordinator.shared
        let session = LoginSessionService.shared
        guard UserSessionStore.shared.currentUser?.userUID == identity.userUID,
              OSSNavigationStore.shared.lastUsableLiceseId() == identity.license else {
            throw MessageRecoveryFailure.invalidIdentity
        }
        do {
            try await connection.restoreCachedConnection(lastLiceseId: identity.license,
                                                         refresh: MessageSessionRecovery.shared.isRetrying)
            guard try await session.restoreCachedSession(lastLiceseId: identity.license, preserveLocalIdentity: true) else {
                throw MessageRecoveryFailure.invalidIdentity
            }
            session.finishStartupRestoration()
        } catch {
            // 旧恢复任务被退出或换号取消后，不得触碰新连接。
            guard !Task.isCancelled, MessageSessionRecovery.shared.identity == identity else { throw CancellationError() }
            connection.reset()
            switch error {
            case UserSessionError.authenticationRejected, UserSessionError.invalidData:
                throw MessageRecoveryFailure.invalidIdentity
            case UserSessionError.keychainFailure, UserSessionError.databaseNotReady:
                throw MessageRecoveryFailure.local(error.localizedDescription)
            case MessageRecoveryFailure.invalidIdentity:
                throw MessageRecoveryFailure.invalidIdentity
            default:
                throw MessageRecoveryFailure.retryable
            }
        }
    }, invalidate: { _ in
        try? LoginSessionService.shared.clearSession()
        RouterTool.shared.resetTabNavigation()
        RouterTool.shared.showAppPage = .login
    })
}
