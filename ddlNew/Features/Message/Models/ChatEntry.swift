//
//  ChatEntry.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

/// 本地演示聊天记录；消息标识保持稳定以支持重复举报检查。
struct ChatEntry: Identifiable {
    let id: String
    let text: String
    let isOutgoing: Bool
    let time: String

    init(id: String = UUID().uuidString, text: String, isOutgoing: Bool, time: String) {
        self.id = id
        self.text = text
        self.isOutgoing = isOutgoing
        self.time = time
    }
}
