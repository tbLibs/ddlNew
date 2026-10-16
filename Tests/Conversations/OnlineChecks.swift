//
//  OnlineChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/16.
//

import Foundation

// 仅替代外部SDK数据库；映射、快照发布与辅助功能文案执行提取的生产源码。
final class LingIMFriendModel {
    var onlineStatus = true
    var disableStatus = 0
    var avatar: String? = "avatar"
    var remarks: String? = "好友"
    var nickname: String?
    var userName: String?
}
final class LingIMSessionModel {
    var sessionStatus = 1
    var sessionID: String?
    var sessionType: SDKKind
    var draftDict: NSDictionary?
    var sessionLatestMessage: NoaIMChatMessageModel?
    var sessionLatestTime: Int64 = 1000
    var sessionAvatar: String?
    var sessionName: String? = "会话"
    var sessionUnreadCount = 3
    var readTag = 0
    var sessionTop = true
    var sessionNoDisturb = false
    init(_ id: String, type: Int = 1) { sessionID = id; sessionType = SDKKind(rawValue: type) }
}
struct SDKKind { let rawValue: Int }
final class NoaIMChatMessageModel {}
final class NoaIMSDKManager {
    static let sdk = NoaIMSDKManager()
    var userUID = "me"
    var models: [LingIMSessionModel] = []
    var friends: [String: LingIMFriendModel] = [:]
    static func sharedTool() -> NoaIMSDKManager { sdk }
    func myUserID() -> String { userUID }
    func isUserDatabaseReady() -> Bool { true }
    func toolGetMySessionListExcept(_ excluded: String) -> Any? { models }
    func toolCheckMyFriend(with id: String) -> LingIMFriendModel? { friends[id] }
    func toolGetLatestChatMessage(withSessionID id: String) -> NoaIMChatMessageModel? { nil }
}
enum UserSessionError: Error { case databaseNotReady }
enum ConversationsClientError: Error { case cacheReadFailed }
enum ConversationPreview {
    static func text(for message: NoaIMChatMessageModel?, kind: ConversationKind, userUID: String, sdk: NoaIMSDKManager) -> String { "正文" }
}

@main struct OnlineChecks {
    @MainActor static func main() async throws {
        var checks = 0, failures = 0
        func check(_ value: Bool, _ reason: String) { checks += 1; if !value { failures += 1; print("FAIL: " + reason) } }
        // 缺少上线字段的旧生产快照按未显示处理，先复现漏标而非测试编译失败。
        func isOnline(_ value: ConversationRecord) -> Bool {
            Mirror(reflecting: value).children.first { $0.label == "isOnline" }?.value as? Bool ?? false
        }
        let sdk = NoaIMSDKManager.sdk
        let peer = LingIMFriendModel(), groupFriend = LingIMFriendModel(), deleted = LingIMFriendModel()
        deleted.disableStatus = 4
        sdk.models = [LingIMSessionModel("peer"), LingIMSessionModel("group", type: 2), LingIMSessionModel("missing"), LingIMSessionModel("deleted")]
        sdk.friends = ["peer": peer, "group": groupFriend, "deleted": deleted]
        let client = ProductionClient(), store = ConversationsStore(client: ProductionClient())
        var values = try await client.loadConversations(for: "me")
        check(isOnline(values[0]), "在线好友进入会话快照")
        check(!isOnline(values[1]), "同ID好友在线也不能给群聊标在线")
        check(!isOnline(values[2]) && !isOnline(values[3]), "无好友记录与注销账号不显示在线")
        check(ProductionRow().accessibilityLabel(for: values[0]).contains("在线"), "在线状态随整行VoiceOver文案读取")
        store.prepare(for: "me"); await store.reload()
        check(store.conversations.first(where: { $0.id == "peer" }).map(isOnline) == true, "真实Store发布在线快照")
        let order = store.conversations.map(\.id), unread = store.totalUnreadCount
        peer.onlineStatus = false
        await store.reload()
        check(store.conversations.first(where: { $0.id == "peer" }).map(isOnline) == false, "好友下线后同会话即时移除在线状态")
        check(store.conversations.map(\.id) == order && store.totalUnreadCount == unread, "上下线不改变置顶排序和未读数")
        values = try await client.loadConversations(for: "me")
        check(!ProductionRow().accessibilityLabel(for: values[0]).contains("在线"), "下线不残留在线辅助功能文案")
        peer.onlineStatus = true; await store.reload()
        check(store.conversations.first(where: { $0.id == "peer" }).map(isOnline) == true, "重新上线可恢复标识")
        store.prepare(for: "other"); sdk.userUID = "other"; sdk.models = []; await store.reload()
        check(store.conversations.isEmpty, "切换账号不保留旧在线会话")
        print("Conversation online checks: \(checks - failures)/\(checks) passed")
        if failures > 0 { exit(1) }
    }
}
