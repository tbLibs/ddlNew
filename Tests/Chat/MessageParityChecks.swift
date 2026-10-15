import Foundation

@main struct MessageParityChecks {
    /// 先固定系统事件与正文的边界，避免空气泡也被计为可读或可选正文。
    static func main() {
        let event = ChatMessageRecord(localID: "event", conversationID: "g", senderID: "system", senderName: "", type: 1000, timestamp: 1, state: .sent)
        precondition(!event.isBody, "系统事件不能成为可读正文")
        precondition(!event.isVisible)
        var visible = event; visible.text = "你修改了群名称"
        precondition(visible.isVisible && !visible.isBody)
        var removed = visible; removed.status = .deleted
        precondition(!removed.isVisible)
        var card = ChatMessageRecord(localID: "card", conversationID: "g", senderID: "B", senderName: "B", type: 6, timestamp: 1)
        card.cardUID = "C"
        precondition(card.cardProfileID == "C", "名片入口必须指向名片本人而不是消息发送者")
        card.status = .recalled; precondition(card.cardProfileID == nil)
        card.status = .normal; card.isCompatible = false; precondition(card.cardProfileID == nil)
        card.isCompatible = true; card.cardUID = ""; precondition(card.cardProfileID == nil)
        let recallControl = ChatMessageRecord(localID: "recall-control", serverID: "20", conversationID: "g", senderID: "B", senderName: "B", type: 8, timestamp: 20, state: .sent)
        precondition(!recallControl.isVisible, "撤回控制记录不能成为第二个撤回气泡")
        var recalledOriginal = ChatMessageRecord(localID: "original", serverID: "10", conversationID: "g", senderID: "B", senderName: "B", text: "引用🙂", timestamp: 10, state: .sent, referenceID: "9")
        recalledOriginal.status = .recalled
        let displayed = [recalledOriginal, recallControl].filter(\.isVisible)
        precondition(displayed.count == 1 && displayed[0].localID == "original" && displayed[0].timestamp == 10, "一条撤回只保留原消息身份和时间的占位")
        precondition(displayed[0].displayText == "消息已撤回" && !displayed[0].isBody)
        print("Message visibility/card checks: 11 passed")
    }
}
