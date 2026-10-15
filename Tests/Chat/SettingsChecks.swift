import Foundation
@MainActor final class SettingsClientFake: ChatSettingsClient {
    var fails = false
    var detail = ChatGroupDetail(id: "g", name: "群", avatar: "", role: 2, isActive: true, nickname: "", isAllMuted: false, isPrivateChat: false, requiresApproval: false, historyVisible: true, qrVisible: true, remindEnabled: true, memberCount: 1)
    var receivedAction: ChatGroupAction?
    var suspendAction = false
    var pendingAction: CheckedContinuation<Void, Error>?
    /// 固定真实快照合同供提交成败测试。
    func load(context: ChatContext) async throws -> ChatSettingsSnapshot { ChatSettingsSnapshot(isPinned: false, isMuted: false, canClear: true, group: detail) }
    /// 置顶无需外部服务。
    func setConversation(context: ChatContext, pinned: Bool?, muted: Bool?) async throws {}
    /// 清空无需外部服务。
    func clear(context: ChatContext) async throws {}
    /// 注入失败必须返回失败，不能使选人页提前关闭。
    func groupAction(_ action: ChatGroupAction, context: ChatContext) async throws {
        receivedAction = action
        if fails { throw ChatClientError.unavailable("服务器拒绝") }
        if suspendAction { try await withCheckedThrowingContinuation { pendingAction = $0 } }
        if case .remove(let ids, _) = action { detail.members.removeAll { ids.contains($0.id) }; detail.memberCount = detail.members.count }
    }
    /// 关闭取消等待。
    func close() {}
}
@main struct SettingsChecks {
    /// 对生产Store验证提交结果及账号隔离。
    @MainActor static func main() async {
        let client = SettingsClientFake(); let store = ChatSettingsStore(client: client)
        let context = ChatContext(userUID: "owner", tenantID: "t", sessionID: UUID(), route: ChatRoute(id: "g", kind: .group, title: "群", avatarURL: ""))
        await store.open(context)
        client.fails = true
        let failed = await store.groupAction(.rename("新群"))
        precondition(!failed && store.errorMessage != nil, "失败须保留选择并显示错误")
        client.fails = false
        let succeeded = await store.groupAction(.rename("新群"))
        precondition(succeeded && store.errorMessage == nil, "成功才允许选择器关闭")
        let tooLong = await store.groupAction(.nickname(String(repeating: "🙂", count: 16)))
        precondition(!tooLong, "昵称按旧UTF16上限30校验")
        store.close(); precondition(store.errorMessage == nil && store.snapshot == nil, "退出清除旧账号错误")
        await store.open(context)
        store.leaveSettingsView(presentingChild: true)
        precondition(store.snapshot?.group?.role == 2, "群头像子页必须保留共享设置权限快照")
        let avatarSaved = await store.groupAction(.avatar("uploaded-group-avatar"))
        precondition(avatarSaved, "进入群头像子页后共享Store仍可提交头像")
        client.detail.members = [ChatGroupMember(id: "owner", name: "群主", avatar: "", role: 2, isDeleted: false), ChatGroupMember(id: "admin", name: "管理", avatar: "", role: 1, isDeleted: false), ChatGroupMember(id: "member", name: "成员", avatar: "", role: 0, isDeleted: false)]
        client.detail.memberCount = 3; client.detail.membersSyncReady = true
        await store.reload()
        var selection = ChatGroupRemovalSelection()
        selection.toggle("admin", detail: client.detail, userUID: "owner")
        selection.toggle("member", detail: client.detail, userUID: "owner")
        let removal = selection.action(detail: client.detail, userUID: "owner", deleteMessages: true)!
        client.fails = true
        let removalFailed = await store.groupAction(removal)
        precondition(!removalFailed && store.snapshot?.group?.members.count == 3 && selection.selectedIDs == ["admin", "member"], "拒绝移除时保留名单与多选草稿")
        client.fails = false
        let removalSucceeded = await store.groupAction(removal)
        precondition(removalSucceeded && client.receivedAction == .remove(["admin", "member"], deleteMessages: true), "真实Store传递整批UID和删除消息选项")
        precondition(store.snapshot?.group?.members.map(\.id) == ["owner"] && store.snapshot?.group?.memberCount == 1, "成功后读取最新名单和人数，保留群主")
        store.leaveSettingsView(presentingChild: false)
        precondition(store.snapshot == nil, "真正退出设置时必须清理状态")
        await store.open(context)
        client.suspendAction = true
        let oldDissolve = Task { await store.groupAction(.dissolve) }
        for _ in 0..<1000 { if client.pendingAction != nil { break }; await Task.yield() }
        precondition(client.pendingAction != nil, "等待旧解散请求挂起")
        store.close(); await store.open(context)
        client.pendingAction?.resume(returning: ()); client.pendingAction = nil
        let oldResult = await oldDissolve.value
        precondition(!oldResult && !store.hasLeft && store.snapshot != nil, "设置同context重新打开也不能被旧离群回执关闭")
        client.suspendAction = false; client.fails = true
        let rejectedDeparture = await store.groupAction(.dissolve)
        precondition(!rejectedDeparture && !store.hasLeft, "服务端拒绝解散必须保留当前群设置")
        client.fails = false
        let dissolved = await store.groupAction(.dissolve)
        precondition(dissolved && store.hasLeft, "服务端受理解散后明确标记已离开")
        print("Settings checks: 14 passed")
    }
}
