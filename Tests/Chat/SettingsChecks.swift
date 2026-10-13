import Foundation
@MainActor final class SettingsClientFake: ChatSettingsClient {
    var fails = false
    let detail = ChatGroupDetail(id: "g", name: "群", avatar: "", role: 2, isActive: true, nickname: "", isAllMuted: false, isPrivateChat: false, requiresApproval: false, historyVisible: true, qrVisible: true, remindEnabled: true, memberCount: 1)
    /// 固定真实快照合同供提交成败测试。
    func load(context: ChatContext) async throws -> ChatSettingsSnapshot { ChatSettingsSnapshot(isPinned: false, isMuted: false, canClear: true, group: detail) }
    /// 置顶无需外部服务。
    func setConversation(context: ChatContext, pinned: Bool?, muted: Bool?) async throws {}
    /// 清空无需外部服务。
    func clear(context: ChatContext) async throws {}
    /// 注入失败必须返回失败，不能使选人页提前关闭。
    func groupAction(_ action: ChatGroupAction, context: ChatContext) async throws { if fails { throw ChatClientError.unavailable("服务器拒绝") } }
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
        store.leaveSettingsView(presentingChild: false)
        precondition(store.snapshot == nil, "真正退出设置时必须清理状态")
        print("Settings checks: 7 passed")
    }
}
