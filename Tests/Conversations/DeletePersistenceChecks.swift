import Foundation
import ObjectiveC
protocol NoaToolSessionDelegate {}
struct SDKEnum { var rawValue = 0 }
final class NoaIMChatMessageModel: @unchecked Sendable {
    var msgID: String?; var serviceMsgID: String?; var fromID: String?; var toID: String?
    var chatType = SDKEnum(); var messageType = SDKEnum(); var messageStatus = 1; var backDelInformSwitch = 0
    init(_ mid: String, _ sid: String, peer: String = "B", status: Int = 1) {
        msgID = mid; serviceMsgID = sid; fromID = "A"; toID = peer; messageStatus = status
    }
}
final class LingIMSessionModel { var sessionLatestMessage: NoaIMChatMessageModel? }
final class NoaIMSDKManager: NSObject, @unchecked Sendable {
    static var current = NoaIMSDKManager()
    static func sharedTool() -> NoaIMSDKManager { current }
    var uid = "A"; var writesFail = false
    // 文件缓存模拟跨AUTH/客户端重建；不提供内存删除ID作为保护来源。
    var file: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    func myUserID() -> String { uid }
    func isUserDatabaseReady() -> Bool { true }
    func rows() -> [[String: String]] {
        guard let data = try? Data(contentsOf: file) else { return [] }
        return (try? JSONDecoder().decode([[String: String]].self, from: data)) ?? []
    }
    func decode(_ row: [String: String]) -> NoaIMChatMessageModel {
        NoaIMChatMessageModel(row["mid"]!, row["sid"]!, peer: row["peer"]!, status: Int(row["status"]!)!)
    }
    func toolGetOneChatMessage(withServiceMessageID id: String, sessionID: String) -> NoaIMChatMessageModel? {
        rows().first { $0["sid"] == id && $0["peer"] == sessionID }.map(decode)
    }
    func toolGetOneChatMessage(withMessageID id: String, sessionID: String) -> NoaIMChatMessageModel? {
        rows().first { $0["mid"] == id && $0["peer"] == sessionID }.map(decode)
    }
    func toolInsertOrUpdateChatMessage(with model: NoaIMChatMessageModel) -> Bool {
        guard !writesFail else { return false }
        var rows = rows(); rows.removeAll { $0["mid"] == model.msgID && $0["peer"] == model.toID }
        rows.append(["mid": model.msgID ?? "", "sid": model.serviceMsgID ?? "", "peer": model.toID ?? "", "status": String(model.messageStatus)])
        do { try JSONEncoder().encode(rows).write(to: file); return true } catch { return false }
    }
    func toolInsertOrUpdateChatMessages(with models: [NoaIMChatMessageModel]) { for model in models { _ = toolInsertOrUpdateChatMessage(with: model) } }
    func toolDeleteChatMessage(with model: NoaIMChatMessageModel) -> Bool { model.messageStatus = 0; return toolInsertOrUpdateChatMessage(with: model) }
    func toolSessionListAllRead() {}
    func deleteMessage(_ params: NSMutableDictionary, onSuccess: (Any?, String?) -> Void, onFailure: (Int, String?, String?) -> Void) { onSuccess(true, nil) }
    func recallMessage(_ params: NSMutableDictionary, onSuccess: (Any?, String?) -> Void, onFailure: (Int, String?, String?) -> Void) { onSuccess(true, nil) }
}
struct SDKChatMessageMapper {
    static func record(_ model: NoaIMChatMessageModel, userUID: String) -> ChatMessageRecord {
        ChatMessageRecord(localID: model.msgID ?? "", serverID: model.serviceMsgID ?? "", conversationID: model.toID ?? "", senderID: model.fromID ?? "", senderName: "", timestamp: 1, state: .sent, status: ChatMessageStatus(rawValue: model.messageStatus)!)
    }
}
struct TestUser { var nickname = "A" }
@MainActor struct UserSessionStore { static let shared = UserSessionStore(); var currentUser: TestUser? { TestUser() } }
@main struct DeletePersistenceChecks {
    @MainActor static func main() async {
        let sdk = NoaIMSDKManager.sharedTool(); defer { try? FileManager.default.removeItem(at: sdk.file) }
        let route = ChatRoute(id: "B", kind: .single, title: "B", avatarURL: "")
        let context = ChatContext(userUID: "A", tenantID: "club", sessionID: UUID(), route: route)
        let client = ProductionDeleteClient()
        let original = NoaIMChatMessageModel("m10", "10")
        precondition(sdk.toolInsertOrUpdateChatMessage(with: original))
        let record = SDKChatMessageMapper.record(original, userUID: "A")
        try! await client.perform(.delete, message: record, context: context)
        precondition(sdk.toolGetOneChatMessage(withServiceMessageID: "10", sessionID: "B")?.messageStatus == 0, "受理后真实缓存写0")
        // 重建SDK/client代表新AUTH；保护必须重新读磁盘墓碑，不能依赖旧页面状态。
        let restarted = NoaIMSDKManager(); restarted.file = sdk.file; NoaIMSDKManager.current = restarted
        let semaphore = DispatchSemaphore(value: 0)
        let delegate = SDKConversationsDelegate(userUID: "A") { event in if case .syncFinished = event { semaphore.signal() } }
        let latest = LingIMSessionModel(); latest.sessionLatestMessage = NoaIMChatMessageModel("server-changed-mid", "10")
        let recalled = NoaIMChatMessageModel("m20", "20", status: 2); precondition(restarted.toolInsertOrUpdateChatMessage(with: recalled))
        let recalledLatest = LingIMSessionModel(); recalledLatest.sessionLatestMessage = NoaIMChatMessageModel("m20", "20")
        let normal = LingIMSessionModel(); normal.sessionLatestMessage = NoaIMChatMessageModel("m30", "30")
        delegate.imSdkSessionSyncStart(); delegate.cimToolSessionListUpdate(with: [latest, recalledLatest, normal], topSessionList: [], isFirstPage: true); delegate.imSdkSessionSyncFinish()
        precondition(semaphore.wait(timeout: .now() + 5) == .success)
        precondition(restarted.toolGetOneChatMessage(withServiceMessageID: "10", sessionID: "B")?.messageStatus == 0, "AUTH latest normal不得覆盖磁盘本机删除0")
        precondition(restarted.toolGetOneChatMessage(withServiceMessageID: "20", sessionID: "B")?.messageStatus == 2, "AUTH latest normal不得覆盖撤回2")
        precondition(restarted.toolGetOneChatMessage(withServiceMessageID: "30", sessionID: "B")?.messageStatus == 1, "新正常条仍应写库")
        precondition(restarted.rows().count == 3, "同SID不同本地ID不能另建正常条绕过删除墓碑")
        recalledLatest.sessionLatestMessage?.serviceMsgID = nil
        delegate.imSdkSessionSyncStart(); delegate.cimToolSessionListUpdate(with: [recalledLatest], topSessionList: [], isFirstPage: true); delegate.imSdkSessionSyncFinish()
        precondition(semaphore.wait(timeout: .now() + 5) == .success)
        precondition(restarted.toolGetOneChatMessage(withServiceMessageID: "20", sessionID: "B")?.messageStatus == 2, "缺SID时仍按同会话本地ID保护墓碑")
        let second = ProductionDeleteClient(); restarted.writesFail = true
        let normalRecord = SDKChatMessageMapper.record(normal.sessionLatestMessage!, userUID: "A")
        do { try await second.perform(.delete, message: normalRecord, context: context); preconditionFailure("本机写0失败不得返回成功") } catch {}
        precondition(restarted.toolGetOneChatMessage(withServiceMessageID: "30", sessionID: "B")?.messageStatus == 1)
        var failed = normalRecord; failed.state = .failed
        do { try await second.perform(.delete, message: failed, context: context); preconditionFailure("失败消息本机删除写失败不得返回成功") } catch {}
        restarted.writesFail = false
        let missing = ChatMessageRecord(localID: "missing", serverID: "missing", conversationID: "B", senderID: "A", senderName: "", timestamp: 1, state: .sent)
        do { try await second.perform(.delete, message: missing, context: context); preconditionFailure("缺真实原条不得仅移除UI当成功") } catch {}
        var drifted = normalRecord; drifted.localID = "server-normalized-mid"
        try! await second.perform(.delete, message: drifted, context: context)
        precondition(restarted.toolGetOneChatMessage(withServiceMessageID: "30", sessionID: "B")?.messageStatus == 0, "本地ID不一致仍按同会话SID删除真实原条")
        print("Delete persistence checks: 11 passed")
    }
}
