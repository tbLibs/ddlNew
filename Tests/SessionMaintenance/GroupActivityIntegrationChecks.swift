import Foundation

enum ChatClientError: Error { case invalidResponse, unavailable(String) }
struct ChatContext: Equatable {
    struct Route: Equatable { enum Kind { case group }; var kind = Kind.group; var id = "group" }
    var userUID = "user"; var tenantID = "tenant"; var sessionID = UUID(); var route = Route()
}
@MainActor final class ChatRuntime {
    static let shared = ChatRuntime(); var context = ChatContext()
    func isCurrent(_ value: ChatContext) -> Bool { value == context }
}
@MainActor final class IMUserAuthenticationService { static let shared = IMUserAuthenticationService(); var isAuthenticated = true }
@MainActor final class AccountSettingsStore {
    static let shared = AccountSettingsStore()
    struct Snapshot { var memberActivePointsInterval: TimeInterval = 3600 }
    var current = Snapshot()
    func matches(userUID: String, tenantID: String, sessionID: UUID) -> Bool {
        let context = ChatRuntime.shared.context
        return userUID == context.userUID && tenantID == context.tenantID && sessionID == context.sessionID
    }
}
extension NSDate { static func getCurrentServerMillisecondTime() -> Int64 { 5_000_000 } }
final class LingIMGroupModel {
    var groupStatus = 1, leaveGroupStatus = 0
    var lastSyncActiviteScoreime: Int64 = 0
}
final class LingIMGroupMemberModel {
    var userUid: String?; var role = 0, disableStatus = 0, activityScroe = 0; var memberIsInGroup = false
    var nicknameInGroup: String?, remarks: String?, userNickname: String?, userAvatar: String?, showName: String?
}
typealias LingIMSuccessCallback = (Any?, String?) -> Void
typealias LingIMFailureCallback = (Int, String?, String?) -> Void
@MainActor final class NoaIMSDKManager: NSObject {
    static let shared = NoaIMSDKManager()
    static func sharedTool() -> NoaIMSDKManager { shared }
    var group = LingIMGroupModel(), members: [String: LingIMGroupMemberModel] = [:]
    var memberPages: [[String: Any]] = [], scorePages: [[String: Any]] = []
    var memberCalls: [NSDictionary] = [], scoreCalls: [NSDictionary] = []
    var memberWrites = 0, cursorWrites = 0
    var failMemberWrite = false, holdScores = false
    var pending: LingIMSuccessCallback?
    func myUserID() -> String { "user" }
    func isUserDatabaseReady() -> Bool { true }
    func toolCheckMyGroup(with: String) -> LingIMGroupModel { group }
    func getGroupMemberList(with params: NSMutableDictionary, onSuccess: LingIMSuccessCallback, onFailure: LingIMFailureCallback) {
        memberCalls.append(params.copy() as! NSDictionary)
        guard !memberPages.isEmpty else { onFailure(1, nil, nil); return }
        onSuccess(memberPages.removeFirst(), nil)
    }
    func groupGetMemberActiviteScore(with params: NSMutableDictionary, onSuccess: @escaping LingIMSuccessCallback, onFailure: LingIMFailureCallback) {
        scoreCalls.append(params.copy() as! NSDictionary)
        if holdScores { pending = onSuccess; return }
        guard !scorePages.isEmpty else { onFailure(1, nil, nil); return }
        onSuccess(scorePages.removeFirst(), nil)
    }
    func imSdkCheckGroupMember(with uid: String, groupID: String) -> LingIMGroupMemberModel? { members[uid] }
    func imSdkInsertOrUpdateGroupMember(_ model: LingIMGroupMemberModel, groupID: String) -> Bool {
        guard !failMemberWrite else { return false }
        members[model.userUid!] = model; memberWrites += 1; return true
    }
    func toolInsertOrUpdateGroupModel(with value: LingIMGroupModel) -> Bool { group = value; cursorWrites += 1; return true }
    func reset() {
        group = LingIMGroupModel(); members = [:]; memberPages = []; scorePages = []
        memberCalls = []; scoreCalls = []; memberWrites = 0; cursorWrites = 0
        failMemberWrite = false; holdScores = false; pending = nil
    }
}
@main struct GroupActivityIntegrationChecks {
    @MainActor static func drain() async { for _ in 0..<40 { try? await Task.sleep(nanoseconds: 1_000_000) } }
    @MainActor static func main() async {
        let coordinator = SDKGroupActivitySyncCoordinator.shared, sdk = NoaIMSDKManager.shared
        func reset() { coordinator.reset(); sdk.reset(); ChatRuntime.shared.context = ChatContext() }
        func memberPage(_ uid: String, current: Int = 1, pages: Int = 1) -> [String: Any] {
            ["items": [["userUid": uid, "userNickname": uid]], "currentPage": current, "pages": pages]
        }
        func scorePage(_ uid: String, current: Int = 1, pages: Int = 1) -> [String: Any] {
            ["records": [["memberUid": uid, "activityScore": 42]], "current": current, "pages": pages]
        }
        reset()
        sdk.memberPages = [memberPage("a", pages: 2), memberPage("b", current: 2, pages: 2)]
        sdk.scorePages = [scorePage("a", pages: 2), scorePage("b", current: 2, pages: 2)]
        coordinator.refreshIfNeeded(context: ChatRuntime.shared.context); await drain()
        precondition(sdk.memberCalls.count == 2 && sdk.members["b"]?.activityScroe == 42 && sdk.cursorWrites == 1, "short nonfinal member page must not skip later members")
        precondition(sdk.memberCalls.allSatisfy { $0["lastSyncTime"] == nil && ($0["pageStart"] as? Int) == 0 }, "full member request follows SDK contract without score cursor")
        precondition(sdk.members["a"]?.memberIsInGroup == true, "full member sync marks membership")
        for badPage in [memberPage("a", current: 2), ["items": [["userUid": "a"], ["userUid": "a"]], "pages": 1, "currentPage": 1]] {
            reset(); sdk.memberPages = [badPage]; sdk.scorePages = [scorePage("a")]
            coordinator.refreshIfNeeded(context: ChatRuntime.shared.context); await drain()
            precondition(sdk.scoreCalls.isEmpty && sdk.cursorWrites == 0, "wrong page or duplicate members must reject sync")
        }
        reset()
        sdk.memberPages = [memberPage("a", pages: 2), ["items": [], "currentPage": 2, "pages": 3]]
        sdk.scorePages = [scorePage("a")]
        coordinator.refreshIfNeeded(context: ChatRuntime.shared.context); await drain()
        precondition(sdk.scoreCalls.isEmpty && sdk.memberWrites == 0 && sdk.cursorWrites == 0, "empty intermediate member page cannot commit")
        reset()
        sdk.memberPages = [memberPage("a")]; sdk.scorePages = [scorePage("a", pages: 2)]
        coordinator.refreshIfNeeded(context: ChatRuntime.shared.context); await drain()
        precondition(sdk.scoreCalls.count == 2 && sdk.memberWrites == 0 && sdk.cursorWrites == 0, "failed score page leaves cursor and members unchanged")
        reset()
        sdk.memberPages = [memberPage("a")]; sdk.scorePages = [scorePage("a")]; sdk.failMemberWrite = true
        coordinator.refreshIfNeeded(context: ChatRuntime.shared.context); await drain()
        precondition(sdk.cursorWrites == 0 && sdk.group.lastSyncActiviteScoreime == 0, "member write failure cannot advance cursor")
        reset()
        sdk.memberPages = [memberPage("a")]; sdk.holdScores = true
        coordinator.refreshIfNeeded(context: ChatRuntime.shared.context); await drain()
        let delayed = sdk.pending
        precondition(delayed != nil)
        ChatRuntime.shared.context = ChatContext() // 同UID新认证轮次，不只是换UID。
        coordinator.reset(); delayed?(scorePage("a"), nil); await drain()
        precondition(sdk.memberWrites == 0 && sdk.cursorWrites == 0, "old same-UID session callback cannot write")
        print("Group activity integration: 9 checks passed")
    }
}
