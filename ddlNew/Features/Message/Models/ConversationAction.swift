// Created by taobo on 2026/10/13.
import Foundation

/// 会话操作与消息操作分开，删除会话始终保留聊天记录。
enum ConversationAction: Hashable, Sendable {
    case togglePin, toggleMute, toggleUnread, delete
}
