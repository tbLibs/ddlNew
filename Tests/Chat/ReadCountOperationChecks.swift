import Foundation
import ObjectiveC

@MainActor final class SDKConversationsClient { var observationGeneration = UUID() }
@MainActor protocol ConversationOperationsClient: AnyObject { func perform(_ action: ConversationAction, conversation: ConversationRecord, userUID: String) async throws }
enum UserSessionError: Error { case databaseNotReady }
typealias LingIMSuccessCallback = (Any?, String?) -> Void
typealias LingIMFailureCallback = (Int, String?, String?) -> Void
final class NoaIMChatMessageModel { var serviceMsgID: String?; init(_ id: String) { serviceMsgID = id } }
final class LingIMSessionModel {
    var sessionUnreadCount = 1; var readTag = 0; var sessionTop = false; var sessionNoDisturb = false
    var sessionLatestServerMsgID: String? = "10"
    var sessionLatestMessage: NoaIMChatMessageModel? = NoaIMChatMessageModel("10")
    func clone() -> LingIMSessionModel {
        let copy = LingIMSessionModel(); copy.sessionUnreadCount = sessionUnreadCount; copy.readTag = readTag
        copy.sessionLatestServerMsgID = sessionLatestServerMsgID; copy.sessionLatestMessage = sessionLatestMessage
        return copy
    }
}
@MainActor final class NoaIMSDKManager: NSObject {
    static let instance = NoaIMSDKManager()
    var current = LingIMSessionModel(); var pending: LingIMSuccessCallback?; var params: [String: Any] = [:]
    var failsWrite = false; var writeCount = 0
    static func sharedTool() -> NoaIMSDKManager { instance }
    func myUserID() -> String { "A" }
    func isUserDatabaseReady() -> Bool { true }
    func toolCheckMySession(with id: String) -> LingIMSessionModel? { current.clone() }
    func toolGetLatestChatMessage(withSessionID id: String) -> NoaIMChatMessageModel? { current.sessionLatestMessage }
    func toolUpdateSession(with model: LingIMSessionModel) -> Bool { if failsWrite { return false }; current = model.clone(); writeCount += 1; return true }
    func toolDeleteSessionModel(with model: LingIMSessionModel, andDeleteAllChatModel: Bool) -> Bool { true }
    func conversationReadedStatus(_ values: NSMutableDictionary, onSuccess: @escaping LingIMSuccessCallback, onFailure: @escaping LingIMFailureCallback) { params = values as? [String: Any] ?? [:]; pending = onSuccess }
    func groupConversationTop(_ values: NSMutableDictionary, onSuccess: @escaping LingIMSuccessCallback, onFailure: @escaping LingIMFailureCallback) {}
    func singleConversationTop(_ values: NSMutableDictionary, onSuccess: @escaping LingIMSuccessCallback, onFailure: @escaping LingIMFailureCallback) {}
    func groupConversationPromt(_ values: NSMutableDictionary, onSuccess: @escaping LingIMSuccessCallback, onFailure: @escaping LingIMFailureCallback) {}
    func singleConversationPromt(_ values: NSMutableDictionary, onSuccess: @escaping LingIMSuccessCallback, onFailure: @escaping LingIMFailureCallback) {}
    func deleteServerConversation(_ values: NSMutableDictionary, onSuccess: @escaping LingIMSuccessCallback, onFailure: @escaping LingIMFailureCallback) {}
    func reply(_ accepted: Bool) { let callback = pending; pending = nil; callback?(NSNumber(value: accepted), nil) }
    /// SDK在成功包无data时传nil；只替换真实传输返回值，仍执行生产Operations。
    func replyPayload(_ value: Any?) { let callback = pending; pending = nil; callback?(value, nil) }
}
@main struct ReadCountOperationChecks {
    /// 编译生产Operations完整方法，真实请求起点/等待期间新消息/本地写失败/旧AUTH分别核对。
    @MainActor static func main() async {
        let runtime = ChatRuntime.shared; let sdk = NoaIMSDKManager.sharedTool(); let client = SDKConversationsClient()
        let route = ChatRoute(id: "g", kind: .group, title: "群", avatarURL: "")
        let conversation = ConversationRecord(id: "g", title: "群", avatarURL: "", kind: .group, preview: "", latestTime: nil, unreadCount: 1, isMarkedUnread: false, isPinned: false, isMuted: false, isDraft: false)
        func record(_ id: String) -> ChatMessageRecord { ChatMessageRecord(localID: "m" + id, serverID: id, conversationID: "g", senderID: "B", senderName: "B", timestamp: 1, state: .sent) }
        runtime.activate(userUID: "A", tenantID: "club", sessionID: UUID())
        let context = runtime.context(for: route)!
        SDKChatUnreadObserver.current!.emit(.received(record("10"), ChatReadCountSnapshot(id: "g", kind: .group, count: 1, latestID: "10")))
        let saving = Task { try await client.perform(.toggleUnread, conversation: conversation, userUID: "A") }
        while sdk.pending == nil { await Task.yield() }
        precondition(sdk.params["latestSMsgId"] as? String == "10")
        sdk.current.sessionUnreadCount = 2; sdk.current.sessionLatestServerMsgID = "20"
        // SDK数据库最新正文可能尚未刷新，持久化SID仍是等待期间真实的新消息身份。
        SDKChatUnreadObserver.current!.emit(.received(record("20"), ChatReadCountSnapshot(id: "g", kind: .group, count: 2, latestID: "20")))
        sdk.reply(true); try! await saving.value
        precondition(sdk.current.sessionUnreadCount == 1)
        runtime.savedVisibleRead("10", context: context)
        precondition(runtime.visibleReadCountPlan(context: context, count: 1, latestID: "20") == nil)
        runtime.savedVisibleRead("20", context: context)
        precondition(runtime.visibleReadCountPlan(context: context, count: 1, latestID: "20")!.remaining == 0)

        runtime.activate(userUID: "A", tenantID: "club", sessionID: UUID()); let failedContext = runtime.context(for: route)!
        sdk.current.sessionUnreadCount = 1; sdk.current.sessionLatestServerMsgID = "30"; sdk.current.sessionLatestMessage = NoaIMChatMessageModel("30")
        SDKChatUnreadObserver.current!.emit(.received(record("30"), ChatReadCountSnapshot(id: "g", kind: .group, count: 1, latestID: "30")))
        let failure = Task { try await client.perform(.toggleUnread, conversation: conversation, userUID: "A") }
        while sdk.pending == nil { await Task.yield() }
        sdk.current.sessionUnreadCount = 2; sdk.current.sessionLatestServerMsgID = "40"
        SDKChatUnreadObserver.current!.emit(.received(record("40"), ChatReadCountSnapshot(id: "g", kind: .group, count: 2, latestID: "40")))
        sdk.failsWrite = true; sdk.reply(true)
        do { try await failure.value; preconditionFailure("本地保存失败须报错") } catch {}
        precondition(sdk.current.sessionUnreadCount == 2)
        runtime.savedVisibleRead("30", context: failedContext)
        precondition(runtime.visibleReadCountPlan(context: failedContext, count: 2, latestID: "40") == nil, "受理全清但本地失败也不能恢复旧成员资格")
        runtime.savedVisibleRead("40", context: failedContext)
        precondition(runtime.visibleReadCountPlan(context: failedContext, count: 2, latestID: "40")!.remaining == 1)
        sdk.failsWrite = false

        let stale = Task { try await client.perform(.toggleUnread, conversation: conversation, userUID: "A") }
        while sdk.pending == nil { await Task.yield() }
        let writes = sdk.writeCount
        runtime.activate(userUID: "A", tenantID: "club", sessionID: UUID()); sdk.reply(true)
        do { try await stale.value; preconditionFailure("旧AUTH回复不能写新的计数") } catch {}
        precondition(sdk.writeCount == writes)
        runtime.activate(userUID: "A", tenantID: "club", sessionID: UUID())
        sdk.current.sessionUnreadCount = 0; sdk.current.readTag = 0
        let emptyMark = Task { try await client.perform(.toggleUnread, conversation: conversation, userUID: "A") }
        while sdk.pending == nil { await Task.yield() }
        precondition(sdk.params["readTag"] as? Int == 1, "无未读会话标记未读发真实readTag1")
        // 真实SDK type512事件可能先于操作回执更新会话；不能因此把nil成功误报拒绝。
        sdk.current.readTag = 1; sdk.replyPayload(nil)
        do { try await emptyMark.value } catch { preconditionFailure("SDK成功空回执不能在标记已生效后提示服务端拒绝") }
        precondition(sdk.current.readTag == 1, "nil成功回执保留已确认标记未读")
        let nullClear = Task { try await client.perform(.toggleUnread, conversation: conversation, userUID: "A") }
        while sdk.pending == nil { await Task.yield() }
        sdk.replyPayload(NSNull())
        do { try await nullClear.value } catch { preconditionFailure("NSNull成功包不能误报清除手动未读失败") }
        precondition(sdk.current.readTag == 0 && sdk.current.sessionUnreadCount == 0, "NSNull成功回执按请求清除手动标记")
        let beforeRejection = sdk.writeCount
        let falseMark = Task { try await client.perform(.toggleUnread, conversation: conversation, userUID: "A") }
        while sdk.pending == nil { await Task.yield() }
        sdk.reply(false)
        var rejected = false
        do { try await falseMark.value } catch { rejected = true }
        precondition(rejected && sdk.writeCount == beforeRejection && sdk.current.readTag == 0, "明确false/0拒绝不写会话，不用界面变化当服务端受理")
        for payload: Any in ["true", NSNumber(value: 2), ["accepted": true] as [String: Any]] {
            let unknown = Task { try await client.perform(.toggleUnread, conversation: conversation, userUID: "A") }
            while sdk.pending == nil { await Task.yield() }
            sdk.replyPayload(payload)
            var unknownRejected = false
            do { try await unknown.value } catch { unknownRejected = true }
            precondition(unknownRejected && sdk.writeCount == beforeRejection, "未知非空回执不能宽松猜测受理")
        }
        let oldEmpty = Task { try await client.perform(.toggleUnread, conversation: conversation, userUID: "A") }
        while sdk.pending == nil { await Task.yield() }
        runtime.activate(userUID: "A", tenantID: "club", sessionID: UUID())
        sdk.replyPayload(nil)
        var cancelled = false
        do { try await oldEmpty.value } catch { cancelled = error is CancellationError }
        precondition(cancelled && sdk.writeCount == beforeRejection, "同UID新AUTH拒绝旧空成功回执，不改新数据库或界面")
        runtime.close()
        print("Read count operation integration checks: 16 passed")
    }
}
