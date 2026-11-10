import Foundation

typealias LingIMSuccessCallback = (Any?, String?) -> Void
typealias LingIMFailureCallback = (Int, String?, String?) -> Void
enum ChatClientError: Error { case unavailable(String) }
@MainActor final class ChatRuntime {
    static let shared = ChatRuntime()
    var valid = true
    func isCurrent(_ context: ChatContext) -> Bool { valid }
}
@MainActor final class UserSessionStore {
    static let shared = UserSessionStore()
    struct User { var userUID = "a" }
    var currentUser: User? = User()
}
@MainActor final class OSSConnectionBootstrap {
    static let shared = OSSConnectionBootstrap()
    struct Connection { var lastLiceseId = "t" }
    var current: Connection? = Connection()
}
final class NoaIMChatMessageModel: NSObject {
    var sendTime: Int64 = 1794240000000
    var msgID: String? = "local"
    var serviceMsgID: String? = "server"
}
final class FakeSignInSession: NSObject { var sessionUnreadCount = 2 }
typealias LingIMSessionModel = FakeSignInSession
@MainActor final class NoaIMSDKManager: NSObject {
    static let shared = NoaIMSDKManager()
    static func sharedTool() -> NoaIMSDKManager { shared }
    var uid = "a", ready = true, suspended = false, requestCount = 0, writeCount = 0
    var endpoint = "", parameters: NSDictionary = [:], response: Any = [:]
    var failureMessage: String?
    var pending: LingIMSuccessCallback?
    var session = FakeSignInSession()
    func myUserID() -> String { uid }
    func isUserDatabaseReady() -> Bool { ready }
    func invoke(_ name: String, _ params: NSMutableDictionary, _ success: @escaping LingIMSuccessCallback, _ failure: LingIMFailureCallback) {
        endpoint = name; parameters = params; requestCount += 1
        if let failureMessage { failure(-1, failureMessage, nil); return }
        if suspended { pending = success } else { success(response, nil); success(response, nil) }
    }
    func imSignIn(withInfo p: NSMutableDictionary, onSuccess s: @escaping LingIMSuccessCallback, onFailure: LingIMFailureCallback) { invoke("info", p, s, onFailure) }
    func imSignIn(withRecord p: NSMutableDictionary, onSuccess s: @escaping LingIMSuccessCallback, onFailure: LingIMFailureCallback) { invoke("records", p, s, onFailure) }
    func imSignIn(withIntergralDetail p: NSMutableDictionary, onSuccess s: @escaping LingIMSuccessCallback, onFailure: LingIMFailureCallback) { invoke("points", p, s, onFailure) }
    func imSignIn(withRule p: NSMutableDictionary, onSuccess s: @escaping LingIMSuccessCallback, onFailure: LingIMFailureCallback) { invoke("rule", p, s, onFailure) }
    func imSignInRecord(withSign p: NSMutableDictionary, onSuccess s: @escaping LingIMSuccessCallback, onFailure: LingIMFailureCallback) { invoke("sign", p, s, onFailure) }
    func messageGetSignInHistoryRecord(with id: String, offset: Int) -> NSArray { [NoaIMChatMessageModel()] }
    func toolCheckMySession(with id: String) -> FakeSignInSession? { session }
    func toolUpdateSession(with session: FakeSignInSession) -> Bool { writeCount += 1; return true }
}

@main struct DailySignInSDKChecks {
    @MainActor static func main() async throws {
        var count = 0
        func check(_ value: Bool, _ label: String) { precondition(value, label); count += 1 }
        let context = ChatContext(userUID: "a", tenantID: "t", sessionID: UUID(), route: ChatRoute(id: "a", kind: .single, title: "", avatarURL: ""))
        let sdk = NoaIMSDKManager.shared, client = SDKDailySignInClient()
        sdk.response = ["isSignIn": 0, "loyalty": "100-200", "signTotalDay": 0, "signTotalLoyalty": 0, "monthTotalDay": 0]
        let info = try await client.info(context: context)
        check(info.todayPoints == "100-200" && !info.signed, "真实适配器保留随机签到积分区间")
        check(sdk.endpoint == "info" && sdk.parameters == ["userUid": "a"], "详情仅传真实UID，重复回调单次收口")
        let month = SignInMonth()
        sdk.response = ["totalLoyalty": 0, "signInRecords": []]
        _ = try await client.records(month: month, context: context)
        check(sdk.endpoint == "records" && sdk.parameters["year"] as? Int == month.year && sdk.parameters["month"] as? Int == month.month, "记录月份与UID合同")
        sdk.response = ["gainIntegral": 0, "useIntegral": 0, "integralRecordVos": []]
        _ = try await client.points(month: month, context: context)
        check(sdk.endpoint == "points" && sdk.parameters["userUid"] as? String == "a", "积分明细接口")
        sdk.response = ["signInSwitch": 0]
        _ = try await client.rule(context: context); check(sdk.endpoint == "rule", "规则接口")
        sdk.response = ["loyalty": "7"]
        check(try await client.sign(context: context) == 7 && sdk.endpoint == "sign" && sdk.parameters.count == 1, "签到不提交本地奖励或日期")
        sdk.failureMessage = "系统未开启签到功能"
        do { _ = try await client.sign(context: context); preconditionFailure("服务端关闭却成功") }
        catch { check(error.localizedDescription == "系统未开启签到功能", "SDK失败回调保留服务端未开启提示") }
        sdk.failureMessage = nil
        sdk.response = false
        do { _ = try await client.sign(context: context); preconditionFailure("false受理") } catch { count += 1 }
        let reminders = try client.reminders(sessionID: "s", offset: 0, context: context)
        check(reminders.first?.id == "server" && sdk.session.sessionUnreadCount == 0 && sdk.writeCount == 1, "本地提醒映射与清读")
        _ = try client.reminders(sessionID: "s", offset: 15, context: context)
        check(sdk.writeCount == 1, "加载更早提醒不再次清读")
        let before = sdk.requestCount; sdk.uid = "other"
        do { _ = try await client.sign(context: context); preconditionFailure("旧用户请求发出") } catch { count += 1 }
        check(sdk.requestCount == before, "错账号在发送前拒绝")
        sdk.uid = "a"; sdk.suspended = true
        let task = Task { try await client.sign(context: context) }
        while sdk.pending == nil { await Task.yield() }
        ChatRuntime.shared.valid = false; sdk.pending?(["loyalty": 8], nil)
        do { _ = try await task.value; preconditionFailure("旧AUTH回执消费") } catch { count += 1 }
        ChatRuntime.shared.valid = true; sdk.pending = nil
        let cancelled = Task { try await client.sign(context: context) }
        while sdk.pending == nil { await Task.yield() }
        client.cancel(); sdk.pending?(["loyalty": 8], nil)
        do { _ = try await cancelled.value; preconditionFailure("取消回执消费") } catch { count += 1 }
        print("PASS: \(count) production SDK adapter checks")
    }
}
