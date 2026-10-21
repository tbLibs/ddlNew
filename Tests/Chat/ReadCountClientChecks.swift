import Foundation
import ObjectiveC
@MainActor final class MMKV {
    static let store = MMKV()
    var values: [String: String] = ["other": "15"]
    static func `default`() -> MMKV? { store }
    func object(of: AnyClass, forKey: String) -> Any? { values as NSDictionary }
    func set(_ object: NSDictionary, forKey: String) -> Bool {
        precondition(forKey == "clearReadNumSMsgIdDictKey", "沿SDK既有重连边界key")
        values = object as! [String: String]; return true
    }
}
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
    var sessionMissing = false; var readTag = 0
    var clearReadNumSMsgIdDict: [AnyHashable: Any]?
    var requests: [[String: Any]] = []
    var success: ((Any?, String?) -> Void)?
    var failure: ((Int, String?, String?) -> Void)?
    func toolGetLatestChatMessage(withSessionID id: String) -> NoaIMChatMessageModel? { messages[latestID]?.copyRecord() }
    func conversationReadedStatus(_ params: NSMutableDictionary, onSuccess: @escaping (Any?, String?) -> Void, onFailure: @escaping (Int, String?, String?) -> Void) {
        requests.append(params as! [String: Any]); success = onSuccess; failure = onFailure
    }
    var sessionWrites = 0; var bodyWrites = 0; var wireEntries: [[String]] = []
    func myUserID() -> String { "A" }
    func isUserDatabaseReady() -> Bool { true }
    func toolCheckMySession(with id: String) -> LingIMSessionModel? { if sessionMissing { return nil }; let value = LingIMSessionModel(); value.sessionUnreadCount = count; value.readTag = readTag; value.sessionLatestServerMsgID = latestID; return value }
    func toolGetOneChatMessage(withServiceMessageID id: String, sessionID: String) -> NoaIMChatMessageModel? { messages[id]?.copyRecord() }
    func toolSendChatMessage(with model: NoaIMChatMessageModel) { wireEntries.append(model.sMsgIdArray as? [String] ?? []) }
    func toolInsertOrUpdateChatMessage(with model: NoaIMChatMessageModel) -> Bool {
        guard !bodyFails, let id = model.serviceMsgID else { return false }
        messages[id] = model.copyRecord(); bodyWrites += 1; return true
    }
    func toolUpdateSession(with model: LingIMSessionModel) -> Bool {
        guard !sessionFails else { return false }; count = model.sessionUnreadCount; readTag = model.readTag; sessionWrites += 1; return true
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
    /// 生产打开方法覆盖同步初值、快速离开、回执乱序及本机写入失败。
    @MainActor static func openingChecks() async {
        let runtime = ChatRuntime.shared
        for kind in [ConversationKind.single, .group] {
            runtime.activate(userUID: "A", tenantID: "club", sessionID: UUID())
            let context = runtime.context(for: ChatRoute(id: "g", kind: kind, title: "聊天", avatarURL: ""))!
            MMKV.store.values = ["other": "15"]
            let sdk = ReadCountSDK(); sdk.count = 3; sdk.readTag = 1
            let old = sdk.add("20")
            SDKChatUnreadObserver.current!.emit(.authoritative(ChatReadCountSnapshot(id: "g", kind: kind, count: 3, latestID: "20")))
            let client = ProductionReadClient(context: context, sdk: sdk, validSession: { runtime.isCurrent($0) })
            var errors: [String] = []
            try! client.clearConversationUnread(context: context) { errors.append($0) }
            precondition(sdk.count == 0 && sdk.readTag == 0, "单群启动已有未读在开页同步清零")
            precondition(sdk.bodyWrites == 0 && sdk.wireEntries.isEmpty && sdk.messages["20"]?.chatMessageReaded == false, "角标清除不伪造正文或语音已读")
            precondition(MMKV.store.values == ["other": "15", "g": "20"] && sdk.clearReadNumSMsgIdDict?["g"] as? String == "20", "记录进入时已清边界，重连和当前同步不能恢复旧计数")
            let params = sdk.requests[0]
            precondition(params["userUid"] as? String == "A" && params["peerUid"] as? String == "g" && params["latestSMsgId"] as? String == "20" && params["readTag"] as? Int == 0 && params["dialogType"] as? Int == (kind == .group ? 1 : 0), "使用旧端协议和进入时边界")
            let new = sdk.add("30"); sdk.count = 1; sdk.latestID = "30"
            SDKChatUnreadObserver.current!.emit(.received(new, ChatReadCountSnapshot(id: "g", kind: kind, count: 1, latestID: "30")))
            sdk.success?(nil, nil)
            try! await client.read([old], context: context)
            precondition(sdk.count == 1 && MMKV.store.values["g"] == "20", "成功回执及旧正文已读不清掉后来新消息或推进原清读边界")
            sdk.failure?(503, nil, nil)
            for _ in 0..<100 where errors.isEmpty { try? await Task.sleep(nanoseconds: 1_000_000) }
            precondition(errors.count == 1, "当前页面同步失败有反馈")
            try! client.clearConversationUnread(context: context) { errors.append($0) }
            precondition(sdk.count == 0 && sdk.requests.count == 2, "再进入使用最新边界同步")
            let writes = sdk.sessionWrites
            client.stop(); sdk.count = 1; sdk.latestID = "40"
            sdk.success?(NSNull(), nil); sdk.failure?(500, nil, nil)
            for _ in 0..<20 { await Task.yield() }
            precondition(sdk.count == 1 && sdk.sessionWrites == writes && errors.count == 1, "快速返回后迟到回执不能写库或报旧错误")
        }
        runtime.activate(userUID: "A", tenantID: "club", sessionID: UUID())
        let context = runtime.context(for: ChatRoute(id: "g", kind: .group, title: "群", avatarURL: ""))!
        let sdk = ReadCountSDK()
        let client = ProductionReadClient(context: context, sdk: sdk, validSession: { runtime.isCurrent($0) })
        sdk.sessionMissing = true
        try! client.checkOpenUnread()
        precondition(sdk.requests.isEmpty && sdk.sessionWrites == 0, "无会话不创建虚假已读或请求")
        sdk.sessionMissing = false; sdk.sessionFails = true
        do { try client.checkOpenUnread(); preconditionFailure("会话写失败必须反馈") } catch {}
        precondition(sdk.count == 1 && sdk.requests.isEmpty, "本机写失败保留未读且不发成功同步")
        sdk.sessionFails = false; sdk.count = 0; sdk.latestID = ""
        var errors: [String] = []
        try! client.clearConversationUnread(context: context) { errors.append($0) }
        precondition(sdk.requests.count == 1 && sdk.requests[0]["latestSMsgId"] == nil, "本机已清也重试服务端同步，空边界不伪造ID")
        for payload in [NSNull(), NSNumber(value: true)] { sdk.success?(payload, nil) }
        sdk.success?(NSNumber(value: false), nil)
        for _ in 0..<100 where errors.isEmpty { try? await Task.sleep(nanoseconds: 1_000_000) }
        precondition(errors.count == 1, "空成功包有效但明确拒绝须反馈")
        runtime.activate(userUID: "A", tenantID: "club", sessionID: UUID())
        do { try client.checkOpenUnread(); preconditionFailure("旧AUTH不能清新账号未读") } catch {}
        precondition(sdk.requests.count == 1, "身份失效不提交请求")
        runtime.close()
        print("Conversation opening unread checks: 21 passed")
    }
    /// 直接执行生产read/flush/stop方法，匿名SDK区分正文成功、会话失败及旧AUTH。
    @MainActor static func main() async {
        await openingChecks()
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
