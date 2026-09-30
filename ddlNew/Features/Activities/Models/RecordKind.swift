//
//  RecordKind.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

/// 参与记录的分类，同时作为当前 Tab 导航栈中的列表路由。
enum RecordKind: String, Hashable {
    case registered = "我的报名"
    case waiting = "候补记录"
    case checkedIn = "签到记录"
    case past = "已参加活动"
}
