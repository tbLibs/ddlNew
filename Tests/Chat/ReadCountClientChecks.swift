import Foundation
import ObjectiveC
struct CIMChatMessageType { let rawValue: UInt; init?(rawValue: UInt) { self.rawValue = rawValue } }
struct CIMChatType { let rawValue: Int; init?(rawValue: Int) { self.rawValue = rawValue } }
final class NoaIMChatMessageModel {
    var record = ChatMessageRecord(localID: "", conversationID: "g", senderID: "B", senderName: "B", timestamp: 1, state: .sent)
    var msgID = ""; var fromID = ""; var toID = ""; var serviceMsgID: String?
    var messageType = CIMChatMessageType(rawValue: 0)!; var chatType = CIMChatType(rawValue: 1)!
    var isAck = true; var sendTime: Int64 = 0; var sMsgIdArray = NSMutableArray()
    var chatMessageReaded = false
    func copyRecord() -> NoaIMChatMessageModel { let result = NoaIMChatMessageModel(); result.record = record; result.serviceMsgID = serviceMsgID; result.chatMessageReaded = chatMessageReaded; return result }
}
final class LingIMSessionModel {
    var sessionUnreadCount = 0; var readTag = 0
    var sessionLatestServerMsgID: String?; var sessionLatestMessage: NoaIMChatMessageModel?
}
struct SDKChatMessageMapper {
    static func record(_ model: NoaIMChatMessageModel, userUID: String) -> ChatMessageRecord { var value = model.record; value.isRead = model.chatMessageReaded; return value }
}
@MainActor final class ReadCountSDK: NSObject {
    var messages: [String: NoaIMChatMessageModel] = [:]
    var count = 1; var latestID = "20"; var sessionFails = false; var bodyFails = false
    var sessionMissing = false
    var sessionWrites = 0; var bodyWrites = 0; var wireEntries: [[String]] = []
    func myUserID() -> String { "A" }
    func isUserDatabaseReady() -> Bool { true }
    func toolCheckMySession(with id: String) -> LingIMSessionModel? { if sessionMissing { return nil }; let value = LingIMSessionModel(); value.sessionUnreadCount = count; value.sessionLatestServerMsgID = latestID; return value }
    func toolGetOneChatMessage(withServiceMessageID id: String, sessionID: String) -> NoaIMChatMessageModel? { messages[id]?.copyRecord() }
    func toolSendChatMessage(with model: NoaIMChatMessageModel) { wireEntries.append(model.sMsgIdArray as? [String] ?? []) }
    func toolInsertOrUpdateChatMessage(with model: NoaIMChatMessageModel) -> Bool {
        guard !bodyFails, let id = model.serviceMsgID else { return false }
        messages[id] = model.copyRecord(); bodyWrites += 1; return true
    }
    func toolUpdateSession(with model: LingIMSessionModel) -> Bool {
        guard !sessionFails else { return false }; count = model.sessionUnreadCount; sessionWrites += 1; return true
    }
    func removeMessageDelegate(_ value: NSObject) {}
    func removeGroupDelegate(_ value: NSObject) {}
    func removeUserDelegate(_ value: NSObject) {}
    func add(_ id: String) -> ChatMessageRecord {
        let record = ChatMessageRecord(localID: "m" + id, serverID: id, conversationID: "g", senderID: "B", senderName: "B", timestamp: 1, state: .sent)
        let model = NoaIMChatMessageModel(); model.record = record; model.serviceMsgID = id; messages[id] = model; return record
    }
}
@main struct ReadCountClientChecks {
    /// 直接执行生产read/flush/stop方法，匿名SDK区分正文成功、会话失败及旧AUTH。
    @MainActor static func main() async {
        let runtime = ChatRuntime.shared; runtime.activate(userUID: "A", tenantID: "club", sessionID: UUID())
        let route = ChatRoute(id: "g", kind: .group, title: "群", avatarURL: ""); let context = runtime.context(for: route)!
        let sdk = ReadCountSDK(); let old = sdk.add("10"); let new = sdk.add("20")
        let observer = SDKChatUnreadObserver.current!
        observer.emit(.received(new, ChatReadCountSnapshot(id: "g", kind: .group, count: 1, latestID: "20")))
        let first = ProductionReadClient(context: context, sdk: sdk, validSession: { runtime.isCurrent($0) })
        sdk.sessionMissing = true
        try! await first.read([], context: context)
        sdk.sessionMissing = false
        try! await first.read([old], context: context)
        precondition(sdk.count == 1 && sdk.messages["10"]?.chatMessageReaded == true, "旧正文标读但屏外新1保留")
        precondition(sdk.wireEntries.last == ["10_B_m10"], "三段已读wire保持原协议")
        try! await first.read([new], context: context)
        precondition(sdk.count == 0 && sdk.messages["20"]?.chatMessageReaded == true)
        let partial = sdk.add("40"); sdk.count = 1; sdk.latestID = "40"
        observer.emit(.received(partial, ChatReadCountSnapshot(id: "g", kind: .group, count: 1, latestID: "40")))
        sdk.sessionFails = true
        do { try await first.read([partial], context: context); preconditionFailure("会话写失败必须保留待扣") } catch {}
        precondition(sdk.messages["40"]?.chatMessageReaded == true && sdk.count == 1)
        first.stop(); sdk.sessionFails = false
        let second = ProductionReadClient(context: context, sdk: sdk, validSession: { runtime.isCurrent($0) })
        try! await second.read([], context: context)
        precondition(sdk.count == 0, "新client在body已读时仍先补扣Runtime债务")
        let guarded = sdk.add("60"); sdk.count = 1; sdk.latestID = "60"
        observer.emit(.received(guarded, ChatReadCountSnapshot(id: "g", kind: .group, count: 1, latestID: "60")))
        sdk.bodyFails = true
        do { try await second.read([guarded], context: context); preconditionFailure("正文写失败必须报错") } catch {}
        precondition(sdk.count == 1 && sdk.messages["60"]?.chatMessageReaded == false)
        sdk.bodyFails = false
        runtime.activate(userUID: "A", tenantID: "club", sessionID: UUID())
        let written = sdk.bodyWrites
        do { try await second.read([guarded], context: context); preconditionFailure("旧AUTH不能写新DB") } catch {}
        precondition(sdk.bodyWrites == written && sdk.count == 1)
        runtime.close()
        print("Read count client integration checks: 8 passed")
    }
}
