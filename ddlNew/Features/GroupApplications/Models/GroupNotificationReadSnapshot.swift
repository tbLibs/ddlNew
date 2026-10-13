// Created by taobo on 2026/10/13.
import Foundation

/// 每次列表响应携带自身已读边界，筛选请求反序返回不会覆盖另一个请求。
nonisolated struct GroupNotificationReadSnapshot: Sendable {
    let userUID: String
    let loginRun: UUID?
    let license: String?
    let messages: [GroupNotificationReadBoundary]
}
