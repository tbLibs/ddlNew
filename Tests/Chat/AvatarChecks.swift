import Foundation

// 只替代真实SDK数据库与登录资料边界，头像选择执行从生产源码提取的方法。
struct Kind { let rawValue: Int }
struct MessageKind { let chatType: Kind }
final class LingIMFriendModel {
    var showName: String? = "好友"
    var remarks: String?
    var nickname: String?
    var avatar: String?
    var disableStatus = 0
}
final class LingIMGroupMemberModel {
    var role = 0
    var remarks: String?
    var nicknameInGroup: String?
    var userNickname: String?
    var userAvatar: String?
    var disableStatus = 0
}
final class NoaIMSDKManager {
    static let instance = NoaIMSDKManager()
    static func sharedTool() -> NoaIMSDKManager { instance }
    var uid = "me"
    var ready = true
    var friend: LingIMFriendModel?
    var member: LingIMGroupMemberModel?
    func myUserID() -> String { uid }
    func isUserDatabaseReady() -> Bool { ready }
    func toolCheckMyFriend(with id: String) -> LingIMFriendModel? { id == "peer" ? friend : nil }
    func imSdkCheckGroupMember(with id: String, groupID: String) -> LingIMGroupMemberModel? { member }
}
struct AvatarUser { let userUID: String; let avatar: String }
@MainActor final class Session { var currentUser: AvatarUser? }

@main struct AvatarChecks {
    @MainActor static func main() {
        var failures: [String] = []
        var count = 0
        func check(_ condition: Bool, _ label: String) {
            count += 1
            if !condition { failures.append(label); print("FAIL: " + label) }
        }
        let sdk = NoaIMSDKManager.instance
        let friend = LingIMFriendModel(); sdk.friend = friend
        var peer = ChatMessageRecord(localID: "received", conversationID: "peer", senderID: "peer", senderName: "好友", avatarURL: "wire/peer.png", timestamp: 1, state: .sent)
        for empty in [nil, "", " \n "] as [String?] {
            friend.avatar = empty
            check(ProductionMapper.metadata(peer, userUID: "me").avatarURL == "wire/peer.png", "空好友缓存保留消息头像: \(String(describing: empty))")
        }
        friend.avatar = "latest/peer.png"
        check(ProductionMapper.metadata(peer, userUID: "me").avatarURL == "latest/peer.png", "有效好友缓存优先于旧消息")
        friend.disableStatus = 4
        check(ProductionMapper.metadata(peer, userUID: "me").avatarURL.isEmpty, "注销好友不恢复历史头像")
        sdk.friend = nil
        check(ProductionMapper.metadata(peer, userUID: "me").avatarURL == "wire/peer.png", "无好友记录保留消息头像")
        let member = LingIMGroupMemberModel(); sdk.member = member
        member.userAvatar = ""
        check(ProductionMapper.metadata(peer, userUID: "me", group: true).avatarURL == "wire/peer.png", "空群成员缓存保留消息头像")
        member.userAvatar = "latest/member.png"
        check(ProductionMapper.metadata(peer, userUID: "me", group: true).avatarURL == "latest/member.png", "有效群成员头像更新")
        member.disableStatus = 4
        check(ProductionMapper.metadata(peer, userUID: "me", group: true).avatarURL.isEmpty, "注销成员不恢复历史头像")
        sdk.uid = "other-account"; friend.disableStatus = 0; sdk.friend = friend
        check(ProductionMapper.metadata(peer, userUID: "me").avatarURL == "wire/peer.png", "旧账号映射不能读取新账号缓存")
        let session = Session(); session.currentUser = AvatarUser(userUID: "me", avatar: "profile/me.png")
        var own = ChatMessageRecord(localID: "pending", conversationID: "peer", senderID: "me", senderName: "我", timestamp: 2)
        check(ProductionAvatar(message: own, own: true, session: session).displayedResource == "profile/me.png", "刚发送的空头像快照使用本人资料")
        own.avatarURL = "history/old-me.png"
        check(ProductionAvatar(message: own, own: true, session: session).displayedResource == "profile/me.png", "本人历史消息使用当前头像")
        check(ProductionAvatar(message: peer, own: false, session: session).displayedResource == "wire/peer.png", "对方消息不使用本人头像")
        peer.avatarURL = "profile/me.png"
        check(ProductionAvatar(message: peer, own: false, session: session).displayedResource == "profile/me.png", "双方相同头像合法")
        session.currentUser = AvatarUser(userUID: "other-account", avatar: "profile/other.png")
        check(ProductionAvatar(message: own, own: true, session: session).displayedResource == "history/old-me.png", "账号不匹配不展示另一账号头像")
        session.currentUser = nil
        check(ProductionAvatar(message: own, own: true, session: session).displayedResource == "history/old-me.png", "缺本人资料时保留消息头像")
        print("头像检查 \(count - failures.count)/\(count) 通过")
        if !failures.isEmpty { exit(1) }
    }
}
