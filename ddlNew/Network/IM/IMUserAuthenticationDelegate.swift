//
//  IMUserAuthenticationDelegate.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation
import NoaChatCore

/// 代理只转发事件；每轮创建独立代理，让旧代理的迟到回调失效。
@MainActor
final class IMUserAuthenticationDelegate: NSObject, NoaToolUserDelegate, NoaToolConnectDelegate {
    private let authenticated: @MainActor @Sendable () -> Void
    private let disconnected: @MainActor @Sendable () -> Void
    private let rejected: @MainActor @Sendable (Int, String) -> Void
    private let tokenRefreshed: @MainActor @Sendable (String) -> Void
    private let httpNodeUpdated: @MainActor @Sendable (String) -> Void

    init(authenticated: @escaping @MainActor @Sendable () -> Void,
         disconnected: @escaping @MainActor @Sendable () -> Void,
         rejected: @escaping @MainActor @Sendable (Int, String) -> Void,
         tokenRefreshed: @escaping @MainActor @Sendable (String) -> Void,
         httpNodeUpdated: @escaping @MainActor @Sendable (String) -> Void) {
        self.authenticated = authenticated
        self.disconnected = disconnected
        self.rejected = rejected
        self.tokenRefreshed = tokenRefreshed
        self.httpNodeUpdated = httpNodeUpdated
    }

    nonisolated func cimToolUserConnectSuccess() {
        Task { @MainActor in authenticated() }
    }

    nonisolated func cimToolDisconnect() {
        Task { @MainActor in disconnected() }
    }

    nonisolated func cimToolConnecting() {
        Task { @MainActor in disconnected() }
    }

    nonisolated func cimToolConnectFail(with error: Error) {
        Task { @MainActor in disconnected() }
    }

    nonisolated func imSdkUserForceLogout(_ type: Int, message: String) {
        // type 是 SDK 转换后的下线类型，不冒充原始 AUTH 回执码。
        Task { @MainActor in rejected(type, message) }
    }

    nonisolated func imSdkRefreshTokenAuthBanned(_ errorCode: Int) {
        Task { @MainActor in rejected(errorCode, "账号认证已失效，请重新登录") }
    }

    nonisolated func imSdkRefreshUsetToken(_ userToken: String, errorMsg msg: String?) {
        guard !userToken.isEmpty else { return }
        Task { @MainActor in tokenRefreshed(userToken) }
    }

    nonisolated func cimUserUpdateHttpNode(_ httpNode: String) {
        Task { @MainActor in httpNodeUpdated(httpNode) }
    }
}
