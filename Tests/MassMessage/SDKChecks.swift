import Foundation

typealias LingIMSuccessCallback = (Any?, String?) -> Void
typealias LingIMFailureCallback = (Int, String?, String?) -> Void
struct ChatContext { let userUID: String }
@MainActor final class ChatRuntime {
    static let shared = ChatRuntime(); var current = true
    func isCurrent(_ context: ChatContext) -> Bool { current }
}
@MainActor final class UserRoleAuthorityStore {
    static let shared = UserRoleAuthorityStore(); var current: Authority? = Authority()
    struct Authority { var enabled = true; func allows(_ key: String) -> Bool { enabled } }
}
struct ChatClientError: Error { static func unavailable(_ text: String) -> ChatClientError { .init() } }
class LingIMGroupModel { var groupName: String? = "Group"; var groupAvatar: String? = "group.png" }
class Friend { var disableStatus = 0; var remarks: String? = "Remark"; var nickname: String? = "Name"; var avatar: String? = "user.png" }
@MainActor final class NoaIMSDKManager {
    static let shared = NoaIMSDKManager()
    static func sharedTool() -> NoaIMSDKManager { shared }
    var uid = "test", ready = true, endpoint = "", params: [String: Any] = [:], syncCount = 0
    var response: Any? = nil, success: LingIMSuccessCallback?, failure: LingIMFailureCallback?, held = false
    func myUserID() -> String { uid }; func isUserDatabaseReady() -> Bool { ready }
    func toolCheckMyGroup(with uid: String) -> LingIMGroupModel? { LingIMGroupModel() }
    func toolCheckMyFriend(with uid: String) -> Friend? { Friend() }
    func reconnectSyncSessionsFromServer() { syncCount += 1 }
    func request(_ endpoint: String, _ params: NSMutableDictionary, _ success: @escaping LingIMSuccessCallback, _ failure: @escaping LingIMFailureCallback) {
        self.endpoint = endpoint; self.params = params as! [String: Any]; self.success = success; self.failure = failure
        if !held { success(response, nil) }
    }
    func groupHairGetMessageList(with p: NSMutableDictionary, onSuccess s: @escaping LingIMSuccessCallback, onFailure f: @escaping LingIMFailureCallback) { request("list", p, s, f) }
    func groupHairGetGroupHairErrorUserList(with p: NSMutableDictionary, onSuccess s: @escaping LingIMSuccessCallback, onFailure f: @escaping LingIMFailureCallback) { request("errors", p, s, f) }
    func groupHairGetGroupHairUserList(with p: NSMutableDictionary, onSuccess s: @escaping LingIMSuccessCallback, onFailure f: @escaping LingIMFailureCallback) { request("users", p, s, f) }
    func groupHairCreateHairGroup(with p: NSMutableDictionary, onSuccess s: @escaping LingIMSuccessCallback, onFailure f: @escaping LingIMFailureCallback) { request("create", p, s, f) }
    func groupHairSendHairMessage(with p: NSMutableDictionary, onSuccess s: @escaping LingIMSuccessCallback, onFailure f: @escaping LingIMFailureCallback) { request("send", p, s, f) }
    func groupHairDeleteHairMessage(with p: NSMutableDictionary, onSuccess s: @escaping LingIMSuccessCallback, onFailure f: @escaping LingIMFailureCallback) { request("delete", p, s, f) }
}
@main struct SDKChecks {
    @MainActor static func main() async throws {
        var count = 0
        func check(_ value: Bool, _ name: String) { guard value else { fatalError("FAIL: \(name)") }; count += 1; print("PASS: \(name)") }
        let client = SDKMassMessageClient(context: .init(userUID: "test")), sdk = NoaIMSDKManager.shared
        sdk.response = ["records": [], "total": 0]
        _ = try await client.load(page: 3)
        check(sdk.endpoint == "list" && sdk.params["pageStart"] as? Int == 30 && sdk.params["pageSize"] as? Int == 15 && sdk.params["userUid"] as? String == "test", "history request uses old pagination and identity")
        let user = MassMessageRecipient(uid: "same", isGroup: false, name: "user"), group = MassMessageRecipient(uid: "same", isGroup: true, name: "group")
        sdk.response = "label"
        let label = try await client.create(label: "标签", recipients: [user, user, group])
        check(label == "label" && sdk.params["userUidList"] as? [String] == ["same"] && sdk.params["groupUidList"] as? [String] == ["same"], "create separates and deduplicates recipient kinds")
        sdk.response = nil
        try await client.send(labelID: "label", type: 0, body: "{\"content\":\"hi\"}")
        check(sdk.params["body"] is String && sdk.params["mtype"] as? Int == 0 && sdk.syncCount == 1, "send string body and empty success trigger conversation sync")
        sdk.response = false
        do { try await client.send(labelID: "label", type: 0, body: "{}"); fatalError("accepted false") } catch {}
        check(sdk.syncCount == 1, "explicit rejection does not sync")
        let record = MassMessageRecord(id: "task", labelID: "label", label: "", sentAt: "", type: 0, status: 2, total: 1, errors: 1, body: [:])
        sdk.response = ["records": [["errorUserUid": "same", "chatType": "1", "errorMsg": "已禁言"]], "total": 1]
        let errors = try await client.recipients(record: record, failures: true, page: 2)
        check(sdk.endpoint == "errors" && sdk.params["taskId"] as? String == "task" && sdk.params["labelId"] as? String == "label", "failure list uses task and label")
        check(errors.records[0].name == "Group" && errors.records[0].error == "已禁言", "recipient display reads SDK metadata and reason")
        sdk.response = NSNull(); try await client.delete(record)
        check(sdk.endpoint == "delete" && sdk.params["taskId"] as? String == "task", "delete uses task ID")
        UserRoleAuthorityStore.shared.current = nil; sdk.endpoint = ""
        do { _ = try await client.create(label: "", recipients: [user]); fatalError("permission bypass") } catch {}
        check(sdk.endpoint.isEmpty, "missing role blocks create before transport")
        UserRoleAuthorityStore.shared.current = .init()
        sdk.held = true; sdk.success = nil
        let pending = Task { try await client.load(page: 1) }
        while sdk.success == nil { await Task.yield() }
        ChatRuntime.shared.current = false
        sdk.success?(["records": [], "total": 0], nil)
        do { _ = try await pending.value; fatalError("stale accepted") } catch {}
        check(!ChatRuntime.shared.current, "AUTH changed during request rejects result")
        ChatRuntime.shared.current = true; sdk.success = nil
        let canceled = Task { try await client.load(page: 1) }
        while sdk.success == nil { await Task.yield() }
        client.cancel(); sdk.success?(["records": [], "total": 0], nil); sdk.success?(["records": [], "total": 0], nil)
        do { _ = try await canceled.value; fatalError("cancel accepted") } catch {}
        check(true, "cancel and duplicate late callbacks finish only once")
        print("\(count) SDK contract checks passed")
    }
}
