import Foundation

@main struct RecallCacheChecks {
    static func main() {
        let original = ChatMessageRecord(localID: "original", serverID: "10", conversationID: "group", senderID: "peer", senderName: "对方", text: "旧正文", timestamp: 10, state: .sent)
        let control = ChatMessageRecord(localID: "control", serverID: "20", conversationID: "group", senderID: "peer", senderName: "对方", type: 8, timestamp: 20, state: .sent)
        let target = [control.id: "10"]

        let samePage = ChatRecallCache.reconcile([original, control], targets: target) { _ in original }
        precondition(samePage.count == 2 && samePage[0].status == .recalled && samePage[1].type == 8,
                     "同页撤回应在首屏发布前更新原条，保留SDK分页条数")
        precondition(samePage.filter(\.isVisible).count == 1, "撤回控制消息不能生成第二条占位")

        let olderPage = ChatRecallCache.reconcile([control], targets: target) { _ in original }
        precondition(olderPage.count == 1 && olderPage[0].serverID == "10" && olderPage[0].status == .recalled,
                     "原条在更早本地页时用撤回占位替换控制消息，首屏不等远端补插")

        let missing = ChatRecallCache.reconcile([control], targets: target) { _ in nil }
        precondition(missing == [control], "本地原条缺失时不能虚构正文")

        var deleted = original; deleted.status = .deleted
        let deletedResult = ChatRecallCache.reconcile([deleted, control], targets: target) { _ in deleted }
        precondition(deletedResult == [deleted, control], "已删除的原条不能因撤回控制记录复活")

        let foreign = ChatMessageRecord(localID: "foreign", serverID: "10", conversationID: "other", senderID: "peer", senderName: "对方", text: "其他会话正文", timestamp: 10, state: .sent)
        let foreignResult = ChatRecallCache.reconcile([control], targets: target) { _ in foreign }
        precondition(foreignResult == [control], "不能从其他会话补入撤回占位")
        print("撤回缓存检查 5/5 通过")
    }
}
