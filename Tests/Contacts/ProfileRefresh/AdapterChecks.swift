import Foundation

final class LingIMFriendModel {
    var nickname: String? = "旧昵称", nicknamePinyin: String? = "jiu", avatar: String? = "old.png"
    var remarks: String? = "我的备注", showName: String? = "我的备注"
    var userType = 0, disableStatus = 0
}
final class SDKContactsDelegate {}
@MainActor final class IMUserAuthenticationService {
    static let shared = IMUserAuthenticationService(); var isAuthenticated = true
}
@MainActor final class OSSNavigationStore {
    static let shared = OSSNavigationStore(); var license: String? = "tenant"
    func lastUsableLiceseId() -> String? { license }
}
final class NoaIMSDKManager {
    static let sdk = NoaIMSDKManager()
    static func sharedTool() -> NoaIMSDKManager { sdk }
    var uid = "self", ready = true, writes = 0
    var friends = ["peer": LingIMFriendModel()]
    var replies: [(Any?, String?) -> Void] = []
    var params: [NSMutableDictionary] = []
    func myUserID() -> String { uid }
    func isUserDatabaseReady() -> Bool { ready }
    func toolCheckMyFriend(with id: String) -> LingIMFriendModel? { friends[id] }
    func toolUpdateMyFriend(with model: LingIMFriendModel) -> Bool { writes += 1; return true }
    func removeUserDelegate(_ delegate: SDKContactsDelegate) {}
    func getUserInfo(with params: NSMutableDictionary, onSuccess: @escaping (Any?, String?) -> Void, onFailure: @escaping (Int, String?, String?) -> Void) {
        self.params.append(params); replies.append(onSuccess)
    }
}
@main struct AdapterChecks {
    @MainActor static func main() async throws {
        let client = SDKContactsClient(), sdk = NoaIMSDKManager.sdk, gate = ContactProfileRequestGate.shared
        let first = Task { try await client.refreshProfile("peer", for: "self") }
        while sdk.replies.isEmpty { await Task.yield() }
        precondition(sdk.params[0]["userUid"] as? String == "peer", "公开资料接口必须查询好友UID")
        sdk.replies.removeFirst()(["nickname": "新昵称", "avatar": "new.png", "remarks": "不能覆盖"], nil)
        try await first.value
        let peer = sdk.friends["peer"]!
        precondition(peer.nickname == "新昵称" && peer.avatar == "new.png" && peer.nicknamePinyin != "jiu")
        precondition(peer.remarks == "我的备注" && peer.showName == "我的备注" && sdk.writes == 1)
        let same = Task { try await client.refreshProfile("peer", for: "self") }
        while sdk.replies.isEmpty { await Task.yield() }
        sdk.replies.removeFirst()(["nickname": "新昵称", "avatar": "new.png"], nil)
        try await same.value
        precondition(sdk.writes == 1, "未改变资料不重复写库广播")
        let stale = Task { try await client.refreshProfile("peer", for: "self") }
        while sdk.replies.isEmpty { await Task.yield() }
        let version = gate.begin(userUID: "self", license: "tenant", friendUID: "peer")
        sdk.replies.removeFirst()(["nickname": "旧响应"], nil)
        try await stale.value
        precondition(peer.nickname == "新昵称" && sdk.writes == 1, "详情的新版本阻止后台旧值覆盖")
        let count = sdk.params.count
        try await client.refreshProfile("peer", for: "self")
        precondition(sdk.params.count == count, "不抢占显式操作")
        gate.finish(version, userUID: "self", license: "tenant", friendUID: "peer")
        let deleted = Task { try await client.refreshProfile("peer", for: "self") }
        while sdk.replies.isEmpty { await Task.yield() }
        sdk.friends.removeAll()
        sdk.replies.removeFirst()(["nickname": "旧好友"], nil)
        try await deleted.value
        precondition(sdk.friends.isEmpty && sdk.writes == 1, "刷新不能重新添加已删除好友")
        sdk.friends["peer"] = LingIMFriendModel()
        let logout = Task { try await client.refreshProfile("peer", for: "self") }
        while sdk.replies.isEmpty { await Task.yield() }
        let late = sdk.replies.removeFirst()
        client.stopObserving(); sdk.uid = "other"
        do { try await logout.value; preconditionFailure("退出应取消等待") } catch {}
        late(["nickname": "旧账号响应"], nil)
        for _ in 0..<20 { await Task.yield() }
        precondition(sdk.writes == 1)
        print("生产资料请求与SDK写库：公开字段合并、备注保护、去重、版本隔离、删除及退出检查通过")
    }
}
