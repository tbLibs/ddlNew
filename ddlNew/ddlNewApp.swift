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
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
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
