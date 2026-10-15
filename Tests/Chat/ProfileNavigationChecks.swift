import SwiftUI

@main struct ProfileNavigationChecks {
    /// 运行生产导航动作和实际NavigationPath，SDK和系统push动画不在离线边界内。
    @MainActor static func main() {
        var failures: [String] = []
        var count = 0
        func check(_ value: Bool, _ name: String) {
            count += 1
            if !value { failures.append(name); print("FAIL: " + name) }
        }
        let original = ChatRoute(id: "peer", kind: .single, title: "旧备注", avatarURL: "old")
        let updated = ChatRoute(id: "peer", kind: .single, title: "新备注", avatarURL: "new", sourceGroupID: "group")
        let single = ProductionProfileNavigation(route: original)
        single.detailDestination = .settings
        single.openChatFromProfile(updated)
        check(single.detailDestination == nil, "同一好友从设置资料发消息，关闭全部聊天子页返回原会话")
        check(single.navigation.path.count == 1, "同一好友不向外层路径追加重复会话")
        single.detailDestination = .profile(ContactsRoute(contactID: "peer"))
        single.openChatFromProfile(updated)
        check(single.detailDestination == nil, "头像直接进入的本人会话资料也返回原聊天")
        let groupRoute = ChatRoute(id: "group", kind: .group, title: "群", avatarURL: "")
        let group = ProductionProfileNavigation(route: groupRoute)
        group.detailDestination = .settings
        group.openChatFromProfile(updated)
        check(group.detailDestination == .chat(updated), "群成员资料替换设置子树为对应好友单聊")
        check(group.navigation.path.count == 1, "群内打开单聊不越过子导航修改外层路径")
        if case .chat(let target) = group.detailDestination {
            check(target.id == "peer" && target.kind == .single && target.sourceGroupID == "group", "保留真实好友UID与来源群权限上下文")
        } else { check(false, "目标必须是聊天而非重复用户资料") }
        let sameIDGroup = ProductionProfileNavigation(route: ChatRoute(id: "peer", kind: .group, title: "同ID群", avatarURL: ""))
        sameIDGroup.detailDestination = .settings
        sameIDGroup.openChatFromProfile(updated)
        check(sameIDGroup.detailDestination == .chat(updated), "群与单聊即使ID相同也不能误返回群聊")
        let closed = ProductionProfileNavigation(route: original)
        closed.detailDestination = .settings; closed.conversationClosed = true
        closed.openChatFromProfile(updated)
        check(closed.detailDestination == .settings && closed.navigation.path.count == 1, "已结束会话不接受迟到的资料导航动作")
        let contact = ContactRecord(id: "peer", nickname: "昵称", remarks: "备注", avatar: "avatar")
        let profile = ProductionContactChat()
        let expected = ChatRoute(id: "peer", kind: .single, title: "备注", avatarURL: "avatar", sourceGroupID: "group")
        group.detailDestination = .settings
        profile.contactChatNavigation = ContactChatNavigationAction(open: group.openChatFromProfile)
        profile.sendMessage(to: contact)
        check(group.detailDestination == .chat(expected) && profile.requestedChat == nil, "资料按钮交给聊天所有者，保留当前展示资料与来源群")
        let standalone = ProductionContactChat()
        standalone.sourceGroupID = nil
        let direct = ChatRoute(id: "peer", kind: .single, title: "备注", avatarURL: "avatar")
        standalone.sendMessage(to: contact)
        check(standalone.requestedChat == direct, "通讯录独立资料打开正确单聊，不附加群来源或走聊天内返回逻辑")
        standalone.destinationVisibilityChanged(false)
        check(standalone.requestedChat == nil, "通讯录发消息后返回资料，系统回调清理本页聊天目标")
        standalone.sendMessage(to: contact)
        check(standalone.requestedChat == direct && standalone.sourceGroupID == nil, "通讯录资料返回后再次发消息仍可进入同一好友聊天")
        if !failures.isEmpty { exit(1) }
        print("资料发消息导航检查：\(count)项通过")
    }
}
