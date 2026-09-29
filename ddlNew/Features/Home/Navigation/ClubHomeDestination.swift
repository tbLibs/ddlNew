//
//  ClubHomeDestination.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

/// 首页的二级页面，与底部四个 Tab 的选中状态分离。
enum ClubHomeDestination: Hashable {
    /// 浏览和筛选俱乐部活动。
    case activities
    /// 查看当前俱乐部介绍、权益及参与规则。
    case club

    var title: String {
        switch self {
        case .activities: "活动"
        case .club: "俱乐部"
        }
    }
}
