//
//  ChatDetailDestination.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//

import Foundation

/// 聊天直属子页共用一个目标，资料发消息时可以整体替换设置/资料子树。
enum ChatDetailDestination: Equatable {
    case settings
    case profile(ContactsRoute)
    case chat(ChatRoute)
}
