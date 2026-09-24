//
//  ddlNewApp.swift
//  ddlNew
//
//  Created by taobo on 2026/9/18.
//

import SwiftUI
import Sentry


@main
struct ddlNewApp: App {
    
    /// 负责启动时配置 Sentry。
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    /// 根页面根据共享路由状态在邀请码、登录和主界面之间切换。
    @StateObject var router = RouterTool.shared

    /// OldVersion 登录与会员页面共用的状态。
    @StateObject private var oldVersionStore = ClubStore()
    
    var body: some Scene {
        WindowGroup {
            Group {
                switch router.showAppPage {
                case .invitationCode:
                    InvitationCodeView()
                case .login:
                    // LoginView() // 新版登录页保留，后续版本恢复使用。
                    LoginScreen()
                case .tabbar:
                    // TabbarView() // 新版主页面保留，后续版本恢复使用。
                    MemberTabs()
                }
            }
            .environmentObject(oldVersionStore)
            .onReceive(oldVersionStore.$stage) { stage in
                // OldVersion 的登录、退出和更换俱乐部结果同步到当前根路由。
                switch stage {
                case .member:
                    router.showAppPage = .tabbar
                case .login:
                    router.showAppPage = .login
                case .invite:
                    router.showAppPage = .invitationCode
                case .splash, .restoreFailed:
                    break
                }
            }
        }
    }
}
