import Foundation
import ObjectiveC
protocol NoaToolSessionDelegate: NSObjectProtocol {}
protocol NoaToolMessageDelegate: NSObjectProtocol {}
struct KindValue { var rawValue: Int }
final class LingIMSessionModel {
    var sessionID: String? = "g"; var sessionType = KindValue(rawValue: 2)
    var sessionUnreadCount = 1; var sessionLatestServerMsgID: String? = "20"
    var sessionLatestMessage: NoaIMChatMessageModel?
}
final class NoaIMChatMessageModel {
    var chatType = KindValue(rawValue: 1)
    var serviceMsgID: String? = "20"
    var record = ChatMessageRecord(localID: "m20", serverID: "20", conversationID: "g", senderID: "B", senderName: "B", timestamp: 1, state: .sent)
}
final class NoaIMSDKManager: NSObject, @unchecked Sendable {
    static let instance = NoaIMSDKManager()
    var session = LingIMSessionModel(); var tenant = "club"
    static func sharedTool() -> NoaIMSDKManager { instance }
    func myUserID() -> String { "A" }
    func mySsoInfo() -> String { tenant }
    func isUserDatabaseReady() -> Bool { true }
    func toolCheckMySession(with id: String) -> LingIMSessionModel? { session.sessionID == id ? session : nil }
}
struct SDKChatMessageMapper {
    static func record(_ model: NoaIMChatMessageModel, userUID: String) -> ChatMessageRecord { model.record }
}
final class CountEvents: @unchecked Sendable {
    private let lock = NSLock(); private var events: [ChatReadCountEvent] = []
    func append(_ event: ChatReadCountEvent) { lock.lock(); events.append(event); lock.unlock() }
    func take() -> [ChatReadCountEvent] { lock.lock(); defer { lock.unlock() }; let result = events; events = []; return result }
}
@main struct ReadCountObserverChecks {
    /// 直接编译生产SDK计数delegate，只有真实receive提供成员身份，SDK归零和旧租户独立验证。
    static func main() {
        let owner = ChatReadCountOwner(userUID: "A", tenantID: "club", sessionID: UUID())
        let events = CountEvents(); let delegate = ProductionUnreadDelegate(owner: owner, changed: { events.append($0) })
        let sdk = NoaIMSDKManager.sharedTool(); let message = NoaIMChatMessageModel()
        delegate.cimToolChatMessageReceive(message)
        let initial = events.take()
        precondition(initial.count == 1)
        if case .received(let value, let counter) = initial[0] { precondition(value.serverID == "20" && counter.count == 1 && counter.latestID == "20") }
        else { preconditionFailure("普通receive是明确计数来源") }
        message.record.isRead = true; delegate.cimToolChatMessageReceive(message); precondition(events.take().isEmpty)
        message.record.isRead = false; message.record.senderName = "本人"
        message.record = ChatMessageRecord(localID: "own", serverID: "own", conversationID: "g", senderID: "A", senderName: "A", timestamp: 1)
        delegate.cimToolChatMessageReceive(message); precondition(events.take().isEmpty)
        message.record = ChatMessageRecord(localID: "event", serverID: "e", conversationID: "g", senderID: "B", senderName: "B", type: 1000, timestamp: 1)
        delegate.cimToolChatMessageReceive(message); precondition(events.take().isEmpty)
        sdk.session.sessionUnreadCount = 0; delegate.cimToolSessionUpdate(with: sdk.session)
        if case .counter(let snapshot) = events.take()[0] { precondition(snapshot.count == 0 && snapshot.id == "g") }
        else { preconditionFailure("SDK全清必须开启新计数epoch") }
        sdk.session.sessionUnreadCount = 2; delegate.cimToolSessionDelete(with: sdk.session)
        if case .counter(let snapshot) = events.take()[0] { precondition(snapshot.count == 0) }
        else { preconditionFailure("删除会话清除旧计数成员") }
        delegate.cimToolSessionListUpdate(with: [sdk.session], topSessionList: [], isFirstPage: true)
        if case .authoritative(let snapshot) = events.take()[0] { precondition(snapshot.count == 2 && snapshot.latestID == "20") }
        else { preconditionFailure("权威分页使旧待扣成员失效") }
        sdk.tenant = "other-club"; delegate.cimToolSessionUpdate(with: sdk.session); precondition(events.take().isEmpty)
        print("Read count SDK observer checks: 9 passed")
    }
}
