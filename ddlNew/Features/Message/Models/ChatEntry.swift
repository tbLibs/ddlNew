//
//  ChatEntry.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

/// 本地聊天记录，区别于 SDK 接收到的真实消息。
struct ChatEntry: Identifiable {
    let id: UUID
    let text: String
    let isOutgoing: Bool
    let time: String

    init(text: String, isOutgoing: Bool, time: String) {
        id = UUID()
        self.text = text
        self.isOutgoing = isOutgoing
        self.time = time
    }
}
