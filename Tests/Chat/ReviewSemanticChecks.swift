import Foundation
@main struct ReviewSemanticChecks {
    /// 使用生产策略验证SDK历史写入选择和协议事件，不将UI合并当数据库保护。
    static func main() {
        var baseline = message("旧正文"); var latest = baseline; latest.text = "已编辑正文"; latest.isRead = true; latest.readCount = 3
        precondition(ChatHistoryCachePolicy.keepCurrent(remote: baseline, current: latest, atRequest: baseline), "等待历史期间已编辑SDK原条必须保留")
        precondition(!ChatHistoryCachePolicy.keepCurrent(remote: latest, current: baseline, atRequest: baseline), "未变更SDK缓存应允许服务端离线新正文更新")
        baseline.status = .deleted
        precondition(ChatHistoryCachePolicy.keepCurrent(remote: message("旧正文"), current: baseline, atRequest: nil), "SDK墓碑不能被正常历史覆盖")
        precondition(!ChatHistoryCachePolicy.keepCurrent(remote: message("服务器正文"), current: baseline, atRequest: baseline), "请求前已存在且期间未变更的删除缓存应以服务器状态校正")
        precondition(ChatHistoryCachePolicy.wasDeletedDuringRequest(current: nil, atRequest: latest), "补页期间已物理删除原条不能重新插入")
        let invalidation = ChatGroupEventPolicy.events(kind: 221, groupID: "g", conversationID: "g")
        precondition(invalidation.contains { if case .permissionsChanged = $0 { return true }; return false }, "个人禁言必须使权限缓存失效")
        let kicked = ChatGroupEventPolicy.events(kind: 204, groupID: "g", conversationID: "g", removedIDs: ["u"], deletesHistory: true)
        precondition(kicked.contains { if case .memberHistoryDeleted(let ids) = $0 { return ids == ["u"] }; return false }, "踢人msgDel必须通知正在显示的成员历史")
        precondition(ChatGroupEventPolicy.events(kind: 221, groupID: "other", conversationID: "g").isEmpty, "其他群事件不能污染当前聊天")
        var queue = ChatGroupRefreshQueue()
        precondition(queue.begin("A") && queue.begin("B"), "不同群可以同时刷新，不能互相取消")
        precondition(!queue.begin("A") && queue.finish("A"), "同群刷新中再变更必须排队回读")
        precondition(!queue.finish("B"), "没有后续变化的群只刷新一次")
        var atStart = message("@成员 正文"); atStart.type = 10
        atStart.mentions = [ChatMentionSegment(id: UUID(), userUID: "u", name: "成员", location: 0, length: 4)]
        var unchanged = atStart; unchanged.mentions[0] = ChatMentionSegment(id: UUID(), userUID: "u", name: "成员", location: 0, length: 4)
        var editedRemote = unchanged; editedRemote.text = "@成员 另一端编辑后的正文"
        precondition(!ChatHistoryCachePolicy.keepCurrent(remote: editedRemote, current: unchanged, atRequest: atStart), "@映射每次产生新片段UUID不能误认为SDK正文变更")
        let permanent = ChatGroupBanRecord(id: "u", name: "成员", avatar: "", expires: "9999-01-01 00:00:00", updatedAt: "")
        precondition(permanent.statusText == "永久禁言", "旧永久禁言以远期日期返回也必须正确识别")
        print("Review semantic checks: 13 passed")
    }
    /// 建立具有ACK双ID的SDK缓存值。
    static func message(_ text: String) -> ChatMessageRecord { ChatMessageRecord(localID: "m", serverID: "s", conversationID: "g", senderID: "u", senderName: "成员", text: text, timestamp: 100, state: .sent) }
}
