//
//  AppStartupCoordinator.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

/// 启动只恢复本地入口。网络连接由实际出现的业务页面触发。
@MainActor
enum AppStartupCoordinator {
    static func restoreLocalEntry() async throws -> ShowAppPageType {
        try Task<Never, Never>.checkCancellation()
        OSSConnectionBootstrap.shared.clearCurrent()
        guard let license = OSSNavigationStore.shared.lastUsableLiceseId() else { return .invitationCode }
        do {
            guard let cached = try UserSessionStore.shared.loadCachedSession(lastLiceseId: license) else { return .login }
            guard cached.credentials.isValid, cached.user.userUID == cached.credentials.userUID,
                  cached.credentials.lastLiceseId == license else { throw UserSessionError.invalidData }
            UserSessionStore.shared.activateCachedUser(cached.user)
            MessageSessionRecovery.shared.prepare(userUID: cached.user.userUID, license: license)
            return .tabbar
        } catch {
            if case UserSessionError.invalidData = error { try? UserSessionStore.shared.clear() }
            LoginSecurityNoticeStore.shared.record(message: error.localizedDescription)
            return .login
        }
    }
}
