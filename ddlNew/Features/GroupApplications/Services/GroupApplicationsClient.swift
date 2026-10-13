// Created by taobo on 2026/10/13.
import Foundation

@MainActor protocol GroupApplicationsClient: AnyObject {
    /// 全局群助手与单群管理使用各自的申请列表接口，固定每页十条。
    func load(userUID: String, groupID: String?, pendingOnly: Bool, page: Int) async throws -> GroupApplicationsPage
    /// 逐条解释批量处理结果，未返回的申请视为未成功。
    func review(userUID: String, records: [GroupApplicationRecord], accept: Bool) async throws -> GroupApplicationOutcome
    /// 群通知页面读取成功后，用系统会话最新消息边界上报已读。
    func markNotificationsRead(userUID: String, snapshot: GroupNotificationReadSnapshot?) async throws
}

extension GroupApplicationsClient {
    /// 离线注入客户端可不连接系统消息接口。
    func markNotificationsRead(userUID: String, snapshot: GroupNotificationReadSnapshot?) async throws {}
}
