//
//  TabType.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

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
