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
            L10n.tr("首页")
        case .message:
            L10n.tr("消息")
        case .contacts:
            L10n.tr("通讯录")
        case .mine:
            L10n.tr("我的")
        }
    }
}
