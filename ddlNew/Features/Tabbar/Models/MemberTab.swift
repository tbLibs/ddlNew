//
//  MemberTab.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

enum MemberTab: String, CaseIterable, Identifiable {
    // 活动与俱乐部下沉为首页内的导航页面，不再占用底部 Tab。
    case home = "首页", messages = "消息", contacts = "通讯录", profile = "我的"
    var id: Self { self }
    var icon: String {
        switch self { case .home: return "house"; case .messages: return "bubble.left.and.bubble.right"; case .contacts: return "person.2"; case .profile: return "person.crop.circle" }
    }
}
