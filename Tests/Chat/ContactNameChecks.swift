//
//  ContactNameChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//

import Foundation

@main struct ContactNameChecks {
    @MainActor static func main() async {
        var failures = 0, count = 0
        func check(_ condition: Bool, _ name: String) { count += 1; if !condition { failures += 1; print("FAIL: " + name) } }
        let sdk = NoaIMSDKManager.instance
        let friend = LingIMFriendModel(); friend.nickname = "真实昵称"; friend.showName = "旧备注"; friend.remarks = "新备注"; sdk.friend = friend
        let member = LingIMGroupMemberModel(); member.remarks = "旧备注"; member.nicknameInGroup = "群内昵称"; member.userNickname = "原昵称"; member.userAvatar = ""; sdk.member = member
        let session = LingIMSessionModel()
        check(ProductionNames.displayTitle(session, id: "peer", kind: .single, sdk: sdk) == "新备注", "消息列表优先读取好友最新备注")
        check(ProductionNames.displayTitle(session, id: "peer", kind: .group, sdk: sdk) == "旧会话名", "群会话名称不被好友备注覆盖")
        var message = ChatMessageRecord(localID: "old", serverID: "server-old", conversationID: "group", senderID: "peer", senderName: "旧备注", avatarURL: "valid-avatar", text: "正文", timestamp: 1, state: .sent)
        check(ProductionNames.metadata(message, userUID: "me", group: true).senderName == "新备注", "群历史映射不采用独立成员表里的旧备注")
        let preview = NoaIMChatMessageModel()
        check(ProductionNames.previewName(preview, kind: .group, sdk: sdk) == "新备注", "群会话摘要作者采用好友最新备注")
        friend.remarks = ""; friend.showName = ""
        check(ProductionNames.displayTitle(session, id: "peer", kind: .single, sdk: sdk) == "真实昵称", "清空备注后消息列表回到昵称")
        check(ProductionNames.metadata(message, userUID: "me", group: true).senderName == "群内昵称", "清空备注后群消息回到群昵称而不是旧备注")
        check(ProductionNames.previewName(preview, kind: .group, sdk: sdk) == "群内昵称", "清空备注后群摘要回到群昵称")
        check(ProductionNames.metadata(message, userUID: "me").senderName == "真实昵称", "空showName不能让单聊作者名称变空")
        var screen = ProductionChatTitle()
        check(screen.chatTitle == "新备注", "单聊标题不冻结在进入时的路由名称")
        screen.contacts.contacts = [NameContact(displayName: "又改备注")]
        check(screen.chatTitle == "又改备注", "当前通讯录变化后单聊标题再次更新")
        screen.contacts.contacts = []; screen.route.title = ""
        check(screen.chatTitle == "peer", "缺资料和旧标题时使用稳定UID而不显示空标题")
        let client = LocationClient(), chat = ChatStore(client: LocationClient())
        let live = ChatStore(client: client)
        let context = ChatContext(userUID: "me", tenantID: "club", sessionID: UUID(), route: ChatRoute(id: "group", kind: .group, title: "群", avatarURL: ""))
        client.page = ChatPage(messages: [message], hasMore: false); await live.open(context)
        friend.remarks = "新备注"
        let listener = ProductionNameDelegate(userUID: "me", conversationID: "group", isGroup: true) { client.callback?($0) }
        listener.cimToolUserFriendChange(friend)
        check(live.messages.first?.senderName == "新备注", "好友资料变化立即刷新已加载的群消息作者")
        check(live.messages.first?.text == "正文" && live.messages.first?.serverID == "server-old", "姓名刷新不覆盖消息正文和服务端身份")
        check(live.messages.first?.avatarURL == "valid-avatar", "空成员头像不能在姓名刷新时抹掉已有头像")
        friend.remarks = ""; listener.cimToolUserFriendChange(friend)
        check(live.messages.first?.senderName == "群内昵称", "当前群消息清空备注后立即回退群昵称")
        sdk.uid = "other"; friend.remarks = "别的账号备注"; listener.cimToolUserFriendChange(friend)
        check(live.messages.first?.senderName == "群内昵称", "旧账号代理不得采用新账号的好友信息")
        sdk.uid = "me"; friend.disableStatus = 4
        check(ProductionNames.displayTitle(session, id: "peer", kind: .single, sdk: sdk) == "账号已注销", "注销好友标题不再展示历史备注")
        live.close(); chat.close(); message.text = ""
        if failures > 0 { exit(1) }
        print("好友备注跨页面检查：\(count)项通过")
    }
}
