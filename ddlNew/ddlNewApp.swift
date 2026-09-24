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
    
    var body: some Scene {
        WindowGroup {
            
            switch router.showAppPage {
            case .invitationCode:
                // 邀请码页面
                InvitationCodeView()
            case .login:
                // 登录页面
                LoginView()
            case .tabbar:
                // tabbar页面
                TabbarView()
            }
        }
    }
}
