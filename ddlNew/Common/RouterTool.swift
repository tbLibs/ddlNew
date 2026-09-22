//
//  RouterTool.swift
//  ddlNew
//
//  Created by taobo on 2026/9/21.
//

import Foundation
import Combine
import SwiftUI

enum TabType: Hashable {
    case main, message, contacts, mine
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

/// app启动显示的页面
enum ShowAppPageType {
    //  邀请码             登录   tabbar
    case invitationCode, login, tabbar
}

class RouterTool: ObservableObject{
    
    static let shared = RouterTool()
    private init() {}
    
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
