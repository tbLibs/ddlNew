import Foundation
struct CurrentMessage { var record: ChatMessageRecord }
struct SDKChatMessageMapper { static func record(_ model: CurrentMessage, userUID: String) -> ChatMessageRecord { model.record } }
@main struct ForwardFreshnessChecks {
    /// 合规等待后必须校验SDK当前记录，原选择快照不能恢复撤回/删除正文。
    static func main() {
        let route = ChatRoute(id: "g", kind: .group, title: "群", avatarURL: "")
        let context = ChatContext(userUID: "A", tenantID: "t", sessionID: UUID(), route: route)
        var record = ChatMessageRecord(localID: "l", serverID: "s", conversationID: "g", senderID: "B", senderName: "B", timestamp: 1, state: .sent)
        func permits(_ value: ChatMessageRecord, active: Bool = true) -> Bool {
            do { try ProductionFreshness.check(original: CurrentMessage(record: value), context: context, currentPermission: ChatPermission(isActive: active)); return true }
            catch { return false }
        }
        precondition(permits(record))
        record.status = .deleted; precondition(!permits(record))
        record.status = .recalled; precondition(!permits(record))
        record.status = .normal; record.isCompatible = false; precondition(!permits(record))
        record.isCompatible = true; precondition(!permits(record, active: false))
        record.state = .failed; precondition(!permits(record))
        print("Forward freshness checks: 6 passed")
    }
}
