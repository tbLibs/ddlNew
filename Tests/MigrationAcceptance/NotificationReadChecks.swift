// Created by taobo on 2026/10/13.
import Foundation
typealias LingIMSuccessCallback = (Any?, Any?) -> Void
typealias LingIMFailureCallback = (Int, Any?, Any?) -> Void

final class NoaIMChatMessageModel {
    var serviceMsgID: String?
    /// SDK形状只携带匿名已读边界，不存储消息正文。
    init(_ id: String) { serviceMsgID = id }
}
final class LingIMSessionModel {
    var sessionID: String?
    var sessionType = NotificationSessionType(rawValue: 5)
    var sessionUnreadCount = 0
    var readTag = 0
    var sessionLatestMessage: NoaIMChatMessageModel?
    /// 匿名群通知记录不包含真实用户或群。
    init(_ id: String, latest: String, unread: Int) { sessionID = id; sessionLatestMessage = NoaIMChatMessageModel(latest); sessionUnreadCount = unread }
}
struct NotificationSessionType { let rawValue: Int }
@MainActor final class LoginSessionService { static let shared = LoginSessionService(); var maintenanceSessionID = UUID() }
struct NotificationPlan { var lastLiceseId = "qa-tenant" }
@MainActor final class OSSConnectionBootstrap { static let shared = OSSConnectionBootstrap(); var current: NotificationPlan? = NotificationPlan() }
@MainActor final class NoaIMSDKManager: NSObject {
    static let shared = NoaIMSDKManager()
    var uid = "qa-me"
    var sessions: [LingIMSessionModel] = []
    var writes = 0
    var request: NSMutableDictionary?
    var success: ((Any?, Any?) -> Void)?
    var failure: ((Int, Any?, Any?) -> Void)?
    var listCallbacks: [LingIMSuccessCallback] = []
    /// 提供SDK形状，原生产方法不访问NoaChatCore或网络。
    static func sharedTool() -> NoaIMSDKManager { shared }
    /// 当前身份仅属于离线样本。
    func myUserID() -> String { uid }
    /// 模拟就绪数据库，无真实数据文件。
    func isUserDatabaseReady() -> Bool { true }
    /// 返回可变样本，让网络等待期间状态真实改变。
    func toolGetMySessionListExcept(_ value: String) -> Any { sessions }
    /// 模拟按系统会话身份取当前消息。
    func toolGetLatestChatMessage(withSessionID id: String) -> NoaIMChatMessageModel? { toolCheckMySession(with: id)?.sessionLatestMessage }
    /// 保存原方法的SDK参数，断言只输出字段是否正确。
    func readedMessage(_ params: NSMutableDictionary, onSuccess: @escaping (Any?, Any?) -> Void, onFailure: @escaping (Int, Any?, Any?) -> Void) {
        request = params; success = onSuccess; failure = onFailure
    }
    /// 列表网络等待期间可注入新系统通知，但仅返回原列表边界。
    func groupNotificationApplyJoinGroupList(withData params: NSMutableDictionary, onSuccess: @escaping LingIMSuccessCallback, onFailure: @escaping LingIMFailureCallback) { listCallbacks.append(onSuccess) }
    /// 单群请求沿同一离线返回形状，测试不操作真实群。
    func groupManagerApplyJoinGroupList(withData params: NSMutableDictionary, onSuccess: @escaping LingIMSuccessCallback, onFailure: @escaping LingIMFailureCallback) { listCallbacks.append(onSuccess) }
    /// SDK回读返回网络等待后最新的会话对象。
    func toolCheckMySession(with id: String) -> LingIMSessionModel? { sessions.first { $0.sessionID == id } }
    /// 记录写次数以证明旧回执没有更改新会话。
    func toolUpdateSession(with model: LingIMSessionModel) -> Bool { writes += 1; return true }
    /// 每个场景独立清空SDK样本与回调。
    func clear() { uid = "qa-me"; sessions = []; writes = 0; request = nil; success = nil; failure = nil; listCallbacks = []; LoginSessionService.shared.maintenanceSessionID = UUID(); OSSConnectionBootstrap.shared.current = NotificationPlan() }
}

@main struct NotificationReadChecks {
    @MainActor static var passed = 0
    @MainActor static var failed = 0
    /// 编译从生产源码原样提取的已读方法，验证参数、ACK、重登录及新通知边界。
    @MainActor static func main() async {
        let sdk = NoaIMSDKManager.shared
        sdk.clear(); let first = LingIMSessionModel("qa-notification", latest: "m1", unread: 10); sdk.sessions = [first]
        let plain = Task { try await ProductionNotificationRead().markNotificationsRead(userUID: "qa-me") }
        while sdk.success == nil { await Task.yield() }
        check(sdk.writes == 0 && sdk.request?["chatType"] as? Int == 5 && sdk.request?["smsgId"] as? String == "m1" && sdk.request?["sendMsgUserUid"] as? String == "qa-notification", "M-021 已读参数系统会话消息且ACK前不写库")
        sdk.success?(nil, nil); _ = try? await plain.value
        check(first.sessionUnreadCount == 0 && sdk.writes == 1, "M-021 同边界ACK后清旧未读")
        sdk.clear(); let growing = LingIMSessionModel("qa-notification", latest: "m1", unread: 10); sdk.sessions = [growing]
        let newer = Task { try await ProductionNotificationRead().markNotificationsRead(userUID: "qa-me") }
        while sdk.success == nil { await Task.yield() }
        growing.sessionLatestMessage = NoaIMChatMessageModel("m2"); growing.sessionUnreadCount = 11
        sdk.success?(nil, nil); _ = try? await newer.value
        check(growing.sessionUnreadCount >= 1, "M-021 ACK前新增通知至少保留1未读")
        sdk.clear(); let synced = LingIMSessionModel("qa-notification", latest: "m1", unread: 10); sdk.sessions = [synced]
        let decreased = Task { try await ProductionNotificationRead().markNotificationsRead(userUID: "qa-me") }
        while sdk.success == nil { await Task.yield() }
        synced.sessionLatestMessage = NoaIMChatMessageModel("m2"); synced.sessionUnreadCount = 1
        sdk.success?(nil, nil); _ = try? await decreased.value
        check(synced.sessionUnreadCount >= 1, "M-021 他端降低旧未读后新增通知不得清零")
        sdk.clear(); let allRead = LingIMSessionModel("qa-notification", latest: "m1", unread: 10); sdk.sessions = [allRead]
        let peerRead = Task { try await ProductionNotificationRead().markNotificationsRead(userUID: "qa-me") }
        while sdk.success == nil { await Task.yield() }
        allRead.sessionLatestMessage = NoaIMChatMessageModel("m2"); allRead.sessionUnreadCount = 0
        sdk.success?(nil, nil); _ = try? await peerRead.value
        check(allRead.sessionUnreadCount == 0, "M-021 最新通知已被他端读完不得造未读")
        sdk.clear(); let staleSession = LingIMSessionModel("qa-notification", latest: "m1", unread: 3); sdk.sessions = [staleSession]
        let stale = Task { try await ProductionNotificationRead().markNotificationsRead(userUID: "qa-me") }
        while sdk.success == nil { await Task.yield() }
        LoginSessionService.shared.maintenanceSessionID = UUID(); sdk.success?(nil, nil)
        do { try await stale.value; check(false, "M-G4 同UID重新登录旧通知ACK失效") } catch { check(sdk.writes == 0 && staleSession.sessionUnreadCount == 3, "M-G4 同UID重新登录旧通知ACK失效") }
        sdk.clear(); let rejected = LingIMSessionModel("qa-notification", latest: "m1", unread: 3); sdk.sessions = [rejected]
        let failure = Task { try await ProductionNotificationRead().markNotificationsRead(userUID: "qa-me") }
        while sdk.failure == nil { await Task.yield() }
        sdk.failure?(500, nil, nil); _ = try? await failure.value
        check(sdk.writes == 0 && rejected.sessionUnreadCount == 3, "M-021 上报失败不先清未读")
        sdk.clear(); var callback: LingIMSuccessCallback?
        let validRequest = Task { try await ProductionNotificationRead().request { success, _ in callback = success } }
        while callback == nil { await Task.yield() }
        callback?(["rows": []], nil)
        check((try? await validRequest.value) != nil, "M-021 相同认证轮次请求可返回")
        callback = nil
        let oldRuntime = Task { try await ProductionNotificationRead().request { success, _ in callback = success } }
        while callback == nil { await Task.yield() }
        LoginSessionService.shared.maintenanceSessionID = UUID(); callback?(["rows": []], nil)
        do { _ = try await oldRuntime.value; check(false, "M-G4 群列表审核共享等待同UID旧轮次拒绝") } catch { check(error is CancellationError, "M-G4 群列表审核共享等待同UID旧轮次拒绝") }
        callback = nil
        let oldTenant = Task { try await ProductionNotificationRead().request { success, _ in callback = success } }
        while callback == nil { await Task.yield() }
        OSSConnectionBootstrap.shared.current?.lastLiceseId = "qa-other-tenant"; callback?(["rows": []], nil)
        do { _ = try await oldTenant.value; check(false, "M-G4 群列表审核共享等待旧租户拒绝") } catch { check(error is CancellationError, "M-G4 群列表审核共享等待旧租户拒绝") }
        sdk.clear(); let duringList = LingIMSessionModel("qa-notification", latest: "m1", unread: 10); sdk.sessions = [duringList]
        let owner = ProductionNotificationRead()
        let pageTask = Task { try await owner.load(userUID: "qa-me", groupID: nil, pendingOnly: false, page: 1) }
        while sdk.listCallbacks.isEmpty { await Task.yield() }
        duringList.sessionLatestMessage = NoaIMChatMessageModel("m2"); duringList.sessionUnreadCount = 11
        sdk.listCallbacks[0](["records": [], "total": 0], nil)
        let page = try! await pageTask.value
        check(page.notifications?.messages.first?.messageID == "m1", "M-021 列表期间新通知不改变该列表已读边界")
        let mark = Task { try await owner.markNotificationsRead(userUID: "qa-me", snapshot: page.notifications) }
        while sdk.success == nil { await Task.yield() }
        check(sdk.request?["smsgId"] as? String == "m1", "M-021 用响应携带的旧消息上报而非等待后最新")
        sdk.success?(nil, nil); _ = try? await mark.value
        check(duringList.sessionUnreadCount >= 1, "M-021 列表尚未包含的新通知保留未读")
        sdk.clear(); let reordered = LingIMSessionModel("qa-notification", latest: "m1", unread: 1); sdk.sessions = [reordered]
        let pageA = Task { try await owner.load(userUID: "qa-me", groupID: nil, pendingOnly: false, page: 1) }
        while sdk.listCallbacks.isEmpty { await Task.yield() }
        reordered.sessionLatestMessage = NoaIMChatMessageModel("m2"); reordered.sessionUnreadCount = 2
        let pageB = Task { try await owner.load(userUID: "qa-me", groupID: nil, pendingOnly: true, page: 1) }
        while sdk.listCallbacks.count < 2 { await Task.yield() }
        sdk.listCallbacks[1](["records": [], "total": 0], nil); let responseB = try! await pageB.value
        sdk.listCallbacks[0](["records": [], "total": 0], nil); let responseA = try! await pageA.value
        check(responseB.notifications?.messages.first?.messageID == "m2" && responseA.notifications?.messages.first?.messageID == "m1", "M-021 筛选反序响应各自保留独立已读边界")
        print("Independent notification reads: \(passed)/\(passed+failed) passed; \(failed) failed")
        if failed > 0 { exit(1) }
    }
    /// 场景失败继续采集全部结果，不输出请求内容。
    @MainActor static func check(_ result: Bool, _ label: String) { if result { passed += 1 } else { failed += 1 }; print("\(result ? "PASS" : "FAIL") \(label)") }
}
