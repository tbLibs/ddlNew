// Created by taobo on 2026/10/13.
import Foundation

enum GlobalSearchKind: String, CaseIterable, Identifiable, Sendable {
    case friend = "好友", group = "群聊", singleMessage = "单聊消息", groupMessage = "群聊消息"
    var id: Self { self }
}
