// Created by taobo on 2026/10/13.
import Foundation

struct GroupApplicationsPage: Sendable {
    let records: [GroupApplicationRecord]
    let total: Int
    let notifications: GroupNotificationReadSnapshot?

    /// 当前请求的通知边界随结果返回，单群审核和离线样本可不提供。
    init(records: [GroupApplicationRecord], total: Int, notifications: GroupNotificationReadSnapshot? = nil) {
        self.records = records; self.total = total; self.notifications = notifications
    }
}
