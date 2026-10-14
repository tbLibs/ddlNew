import Foundation

@main struct GroupChecks {
    /// 角色矩阵从生产策略验证，目标状态改变后必须失去提交资格。
    static func main() {
        let members = [ChatGroupMember(id: "owner", name: "群主", avatar: "", role: 2, isDeleted: false), ChatGroupMember(id: "admin", name: "管理", avatar: "", role: 1, isDeleted: false), ChatGroupMember(id: "member", name: "成员", avatar: "", role: 0, isDeleted: false)]
        var detail = ChatGroupDetail(id: "g", name: "群", avatar: "", role: 2, isActive: true, nickname: "", isAllMuted: false, isPrivateChat: false, requiresApproval: true, historyVisible: false, qrVisible: true, remindEnabled: true, memberCount: 3, members: members)
        check(!ChatGroupPolicy.permits(.setManagers(["owner"], enabled: true), detail: detail, userUID: "owner"), "群主不能被设置为普通管理")
        check(!ChatGroupPolicy.permits(.transferOwner("missing"), detail: detail, userUID: "owner"), "转让不能选择失效成员")
        check(!ChatGroupPolicy.permits(.leave, detail: detail, userUID: "owner"), "群主退出需要先转让")
        detail.role = 1
        check(!ChatGroupPolicy.permits(.remove(["owner"], deleteMessages: true), detail: detail, userUID: "admin"), "管理员不能移除群主")
        check(!ChatGroupPolicy.permits(.remove(["admin"], deleteMessages: false), detail: detail, userUID: "admin"), "不能移除本人")
        check(ChatGroupPolicy.permits(.muteMembers(["member"], minutes: -1), detail: detail, userUID: "admin"), "管理可永久禁言普通成员")
        detail.role = 0
        check(!ChatGroupPolicy.permits(.rename("新群"), detail: detail, userUID: "member"), "降权后禁改群名")
        check(ChatGroupPolicy.permits(.nickname("昵称"), detail: detail, userUID: "member"), "普通成员可改本人昵称")
        check(!ChatGroupPolicy.permits(.invite([members[0]]), detail: detail, userUID: "member"), "不能重复邀请群内成员")
        detail.role = 3
        check(!ChatGroupPolicy.permits(.nickname("昵称"), detail: detail, userUID: "member"), "未确认role3不得开放群提交")
        detail.role = 1
        check(!ChatGroupPolicy.permits(.muteMembers(["member"], minutes: 7), detail: detail, userUID: "admin"), "仅允许真实禁言时长合同")
        detail.membersSyncReady = true
        removalSelectionChecks(members)
        detail.role = 0; detail.members = members + (1...8).map { ChatGroupMember(id: "u" + String($0), name: "成员", avatar: "", role: 0, isDeleted: false) }
        precondition(ChatGroupPreviewPolicy.members(detail).count == 5, "普通预览五名成员")
        detail.role = 1; precondition(ChatGroupPreviewPolicy.members(detail).count == 4 && ChatGroupPreviewPolicy.members(detail).first?.role == 2, "管理预览四名且群主优先")
        check(!ChatGroupPolicy.permits(.remove(["member", "member"], deleteMessages: false), detail: detail, userUID: "admin"), "批量移除不得重复提交同一成员")
        check(ChatGroupPolicy.permits(.remove(["member", "u1"], deleteMessages: true), detail: detail, userUID: "admin"), "管理员可以批量移除普通成员并选择清理消息")
        detail.membersSyncReady = false
        check(!ChatGroupPolicy.permits(.remove(["member"], deleteMessages: false), detail: detail, userUID: "admin"), "名单未同步完成不得批量移除")
        detail.membersSyncReady = true
        detail.isActive = false
        check(!ChatGroupPolicy.permits(.nickname("昵称"), detail: detail, userUID: "member"), "失效群禁所有提交")
        print("Group policy checks: 17 passed; removal selection checks: 12 passed")
    }

    /// 直接执行生产选择状态，捕获错误候选、降权、重复UID和上限边界。
    static func removalSelectionChecks(_ members: [ChatGroupMember]) {
        var detail = ChatGroupDetail(id: "g", name: "群", avatar: "", role: 2, isActive: true, nickname: "", isAllMuted: false, isPrivateChat: false, requiresApproval: false, historyVisible: true, qrVisible: true, remindEnabled: true, memberCount: 3, members: members, membersSyncReady: true)
        precondition(ChatGroupRemovalSelection.candidates(in: detail, userUID: "owner").map(\.id) == ["admin", "member"], "群主可选管理员和普通成员，不可选择自己")
        var selection = ChatGroupRemovalSelection()
        precondition(selection.action(detail: detail, userUID: "owner", deleteMessages: false) == nil, "空选择不能提交")
        selection.toggle("admin", detail: detail, userUID: "owner")
        selection.toggle("member", detail: detail, userUID: "owner")
        precondition(selection.action(detail: detail, userUID: "owner", deleteMessages: true) == .remove(["admin", "member"], deleteMessages: true), "批量UID与删除消息选项应完整保留")
        selection.toggle("member", detail: detail, userUID: "owner")
        precondition(selection.selectedIDs == ["admin"], "再次点击取消选择")
        detail.role = 1
        precondition(selection.action(detail: detail, userUID: "owner", deleteMessages: false) == nil, "降权后的旧选择不得提交")
        selection.reconcile(detail: detail, userUID: "owner")
        precondition(selection.selectedIDs.isEmpty, "降权撤销管理员旧勾选")
        detail.members.append(ChatGroupMember(id: "deleted", name: "注销", avatar: "", role: 0, isDeleted: true))
        detail.members.append(ChatGroupMember(id: "robot", name: "机器人", avatar: "", role: 3, isDeleted: false))
        detail.members.append(members[2])
        precondition(ChatGroupRemovalSelection.candidates(in: detail, userUID: "admin").map(\.id) == ["member"], "管理员只可选择普通成员，候选去重并过滤注销和机器人")
        detail.membersSyncReady = false
        precondition(ChatGroupRemovalSelection.candidates(in: detail, userUID: "admin").isEmpty, "未同步完整名单不得选人")
        detail.membersSyncReady = true
        detail.members = (0...500).map { ChatGroupMember(id: "u\($0)", name: "成员\($0)", avatar: "", role: 0, isDeleted: false) }
        for index in 0..<500 { selection.toggle("u\(index)", detail: detail, userUID: "admin") }
        precondition(!selection.toggle("u500", detail: detail, userUID: "admin") && selection.selectedIDs.count == 500, "第501位不可勾选")
        precondition(selection.toggle("u0", detail: detail, userUID: "admin") && selection.toggle("u500", detail: detail, userUID: "admin"), "达到上限仍可取消并选择另一人")
        precondition(!ChatGroupPolicy.permits(.remove(detail.members.map(\.id), deleteMessages: false), detail: detail, userUID: "admin"), "绕过选择器的501人提交也必须拒绝")
        selection.reconcile(detail: nil, userUID: "admin")
        precondition(selection.selectedIDs.isEmpty, "会话关闭清空失效选择")
    }
    /// 校验失败直接退出，不仅打印结果。
    static func check(_ result: Bool, _ name: String) { if !result { fatalError(name) } }
}
