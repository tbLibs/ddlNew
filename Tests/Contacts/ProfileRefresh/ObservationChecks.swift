import Foundation
protocol NoaToolUserDelegate {}
final class LingIMFriendModel {}
final class IMServerMessage {}
final class FriendDelMessage {}
final class SynchroMessage { let sessionId = "friend" }
enum ConversationsChange { case changed, syncStarted, syncFinished, syncFailed(String) }
final class SDKConversationsDelegate {
    init(userUID: String, onChange: @escaping @Sendable (ConversationsChange) -> Void) {}
    func invalidate() {}
}
final class NoaIMSDKManager {
    static let shared = NoaIMSDKManager()
    static func sharedTool() -> NoaIMSDKManager { shared }
    var users: [SDKContactsDelegate] = []
    func addSessionDelegate(_ delegate: SDKConversationsDelegate) {}
    func removeSessionDelegate(_ delegate: SDKConversationsDelegate) {}
    func addUserDelegate(_ delegate: SDKContactsDelegate) { users.append(delegate) }
    func removeUserDelegate(_ delegate: SDKContactsDelegate) { users.removeAll { $0 === delegate } }
}
@main struct ObservationChecks {
    @MainActor static func main() async {
        var changes = 0
        let client = SDKConversationsClient(), sdk = NoaIMSDKManager.shared
        client.observe(for: "me") { if case .changed = $0 { changes += 1 } }
        let old = sdk.users.first
        old?.cimToolUserFriendChange(LingIMFriendModel())
        for _ in 0..<30 { await Task.yield() }
        guard changes == 1 else { print("FAIL: 好友头像昵称已落库，但消息列表没有收到刷新事件"); exit(1) }
        old?.imSdkUserContactsSyncFinish()
        for _ in 0..<30 { await Task.yield() }
        precondition(changes == 2, "批量好友同步结束也刷新消息列表")
        old?.cimToolUserFriendChange(LingIMFriendModel())
        client.stopObserving()
        for _ in 0..<30 { await Task.yield() }
        precondition(changes == 2 && sdk.users.isEmpty, "退出丢弃排队事件并解除好友代理")
        client.observe(for: "other") { if case .changed = $0 { changes += 1 } }
        old?.cimToolUserFriendChange(LingIMFriendModel())
        for _ in 0..<30 { await Task.yield() }
        precondition(changes == 2, "旧身份不能刷新新账号")
        sdk.users.first?.cimToolUserFriendChange(LingIMFriendModel())
        for _ in 0..<30 { await Task.yield() }
        precondition(changes == 3)
        client.stopObserving()
        print("好友资料到消息列表事件检查通过")
    }
}
