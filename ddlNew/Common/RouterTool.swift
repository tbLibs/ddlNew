//
//  RouterTool.swift
//  ddlNew
//
//  Created by taobo on 2026/9/21.
//

import Foundation
import Combine
import SwiftUI

/// 主界面四个 Tab 的稳定标识，用于选中状态和导航栈切换。
enum TabType: Hashable {
    case main, message, contacts, mine
    /// 与当前 Tab 对应的展示标题。
    var title: String {
        switch self {
        case .main:
            "首页"
        case .message:
            "消息"
        case .contacts:
            "通讯录"
        case .mine:
            "我的"
        }
    }
}

/// App 根页面阶段：邀请码、登录或主 Tab。
enum ShowAppPageType {
    case invitationCode, login, tabbar
}

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
}
