// Created by taobo on 2026/10/13.
import Foundation

/// 系统通知游标在列表请求前保存，不能把等待期间新增通知算作已展示。
nonisolated struct GroupNotificationReadBoundary: Sendable {
    let sessionID: String
    let messageID: String
    let unreadCount: Int
}
