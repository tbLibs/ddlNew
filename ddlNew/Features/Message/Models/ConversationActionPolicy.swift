// Created by taobo on 2026/10/13.
import Foundation

enum ConversationActionPolicy {
    /// 延续旧列表的助手和业务会话限制，不向特殊类型发送普通群聊请求。
    nonisolated static func allowed(for conversation: ConversationRecord) -> [ConversationAction] {
        switch conversation.kind {
        case .single: return conversation.id == "100002" ? [.togglePin, .delete] : [.togglePin, .toggleMute, .toggleUnread, .delete]
        case .group: return [.togglePin, .toggleMute, .toggleUnread, .delete]
        default: return []
        }
    }
}
