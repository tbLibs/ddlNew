//
//  ContactsPageRoute.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 通讯录静态页面也使用值路由，与资料和聊天遵循同一NavigationStack。
nonisolated enum ContactsPageRoute: Hashable {
    case addFriend
    case newFriends
    case qrCode(groupID: String?, title: String)
    case scanner
    case globalSearch
    case groupAssistant
}
