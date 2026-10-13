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
        detail.role = 0; detail.members = members + (1...8).map { ChatGroupMember(id: "u" + String($0), name: "成员", avatar: "", role: 0, isDeleted: false) }
        precondition(ChatGroupPreviewPolicy.members(detail).count == 5, "普通预览五名成员")
        detail.role = 1; precondition(ChatGroupPreviewPolicy.members(detail).count == 4 && ChatGroupPreviewPolicy.members(detail).first?.role == 2, "管理预览四名且群主优先")
        detail.isActive = false
        check(!ChatGroupPolicy.permits(.nickname("昵称"), detail: detail, userUID: "member"), "失效群禁所有提交")
        print("Group policy checks: 14 passed")
    }
    /// 校验失败直接退出，不仅打印结果。
    static func check(_ result: Bool, _ name: String) { if !result { fatalError(name) } }
}
