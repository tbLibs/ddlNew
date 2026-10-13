//
//  AppSessionRouter.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

/// 真实用户会话与根页面之间的路由入口，不使用旧版演示账号判断登录状态。
@MainActor
enum AppSessionRouter {
    /// 只在登录编排全部完成后调用；磁盘缓存、ECDH 或单次接口成功都不能进入主页。
    static func enterMain() {
        guard IMUserAuthenticationService.shared.isAuthenticated,
              UserSessionStore.shared.currentUser != nil else { return }
        RouterTool.shared.resetTabNavigation()
        RouterTool.shared.showAppPage = .tabbar
    }

    /// 账号失效或会话被清理后退出主页；普通断线重连保留当前页面。
    static func handleAuthenticationState(_ state: IMUserAuthenticationState) {
        guard RouterTool.shared.showAppPage == .tabbar else { return }
        switch state {
        case .idle, .failed:
            RouterTool.shared.resetTabNavigation()
            RouterTool.shared.showAppPage = .login
        case .authenticating, .ready, .reconnecting:
            break
        }
    }

    /// 旧版页面只传递退出/更换俱乐部意图，实际凭据、数据库与连接由真实会话层清理。
    static func signOut(changeClub: Bool) async throws {
        do {
            try await LoginSessionService.shared.signOut()
            // 等待期间若另一会话已建立，旧退出不能再改变新用户的入口。
            guard UserSessionStore.shared.currentUser == nil else { return }
            if changeClub { try OSSNavigationStore.shared.clearLastUsableEntry() }
        } catch {
            RouterTool.shared.resetTabNavigation()
            RouterTool.shared.showAppPage = .login
            IMConnectionCoordinator.shared.startCachedReconnect()
            throw error
        }
        RouterTool.shared.resetTabNavigation()
        if changeClub {
            IMConnectionCoordinator.shared.reset()
            OSSConnectionBootstrap.shared.clearCurrent()
            RouterTool.shared.showAppPage = .invitationCode
        } else {
            IMConnectionCoordinator.shared.startCachedReconnect()
            RouterTool.shared.showAppPage = .login
        }
    }
}
