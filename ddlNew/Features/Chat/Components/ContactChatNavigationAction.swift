//
//  ContactChatNavigationAction.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//

import SwiftUI

/// 当前聊天接管所有后代资料页的发消息动作，成员名单再深也不追加外层值路由。
struct ContactChatNavigationAction {
    let open: @MainActor (ChatRoute) -> Void
}

private struct ContactChatNavigationKey: EnvironmentKey {
    nonisolated static var defaultValue: ContactChatNavigationAction? { nil }
}

extension EnvironmentValues {
    var contactChatNavigation: ContactChatNavigationAction? {
        get { self[ContactChatNavigationKey.self] }
        set { self[ContactChatNavigationKey.self] = newValue }
    }
}
