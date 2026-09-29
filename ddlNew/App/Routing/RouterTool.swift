//
//  RouterTool.swift
//  ddlNew
//
//  Created by taobo on 2026/9/21.
//

import Foundation
import Combine
import SwiftUI


/// 各 Tab 导航栈和根页面的共享状态容器。
class RouterTool: ObservableObject{
    
    /// 在根视图与 Tab 容器间共享同一份路由状态。
    static let shared = RouterTool()
    private init() {}
    
    /// 当前选中的 Tab。
    @Published var selectTab: TabType = .main
    
    /// 首页 Path
    @Published var mainRouterPath = NavigationPath()
    
    /// 消息 path
    @Published var messageRouterPath = NavigationPath()
    
    /// 通讯录的path
    @Published var contactsRouterPath = NavigationPath()
    
    /// 我的path
    @Published var mineRouterPath = NavigationPath()
    
    /// app启动需要显示的页面
    @Published var showAppPage: ShowAppPageType = .invitationCode

    /// 账号退出或重新登录时清空旧导航，避免带入上一会话的详情页。
    func resetTabNavigation() {
        selectTab = .main
        mainRouterPath = NavigationPath()
        messageRouterPath = NavigationPath()
        contactsRouterPath = NavigationPath()
        mineRouterPath = NavigationPath()
    }
}
