import Foundation
@MainActor private final class ApplicationsClient: GroupApplicationsClient {
    var page = GroupApplicationsPage(records: [], total: 0)
    var outcome = GroupApplicationOutcome(successfulIDs: [], failedIDs: [])
    var readUsers: [String] = []
    /// 测试真实群通知页的清读调用，不把申请ID当消息ID。
    func markNotificationsRead(userUID: String, snapshot: GroupNotificationReadSnapshot?) async throws { readUsers.append(userUID) }
    /// 返回测试指定页。
    func load(userUID: String, groupID: String?, pendingOnly: Bool, page: Int) async throws -> GroupApplicationsPage { self.page }
    /// 返回批量部分成功，避免整批HTTP成功冒充逐条通过。
    func review(userUID: String, records: [GroupApplicationRecord], accept: Bool) async throws -> GroupApplicationOutcome { outcome }
}
@main private struct Checks {
    /// 验证分页去重、选择仅待审核申请、部分失败提示。
    @MainActor static func main() async {
        let client = ApplicationsClient()
        let first = GroupApplicationRecord(id: "1", groupID: "g", nickname: "A", reason: "", status: 1)
        let second = GroupApplicationRecord(id: "2", groupID: "g", nickname: "B", reason: "", status: 1)
        client.page = GroupApplicationsPage(records: [first, first, second], total: 2)
        let store = GroupApplicationsStore(client: client)
        store.prepare(userUID: "u", groupID: nil)
        await store.reload(pendingOnly: true)
        precondition(store.records.count == 2 && !store.hasMore)
        precondition(client.readUsers == ["u"], "全局群通知加载成功后必须发送系统消息已读")
        store.selectAll()
        client.outcome = GroupApplicationOutcome(successfulIDs: ["1"], failedIDs: ["2"])
        await store.review(accept: true)
        precondition(store.notice == "1 条处理成功，1 条未成功，请刷新后重试")
        store.reset()
        precondition(store.records.isEmpty && store.selectedIDs.isEmpty)
        let readCount = client.readUsers.count
        store.prepare(userUID: "u", groupID: "g")
        await store.reload(pendingOnly: false)
        precondition(client.readUsers.count == readCount, "单群审核不冒充全局系统通知清读")
        print("Group application checks passed")
    }
}
