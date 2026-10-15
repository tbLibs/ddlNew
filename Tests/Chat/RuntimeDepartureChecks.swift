import Foundation

// 只替换SDK和媒体依赖，直接编译生产ChatRuntime检查关闭事件及身份守卫。
@MainActor final class SDKChatNicknameObserver {
    func activate(userUID: String, tenantID: String, sessionID: UUID) {}
    func close() {}
}
@MainActor final class SDKChatUnreadObserver {
    static var current: SDKChatUnreadObserver?
    private var handler: ((ChatReadCountEvent) -> Void)?
    init() { Self.current = self }
    func activate(owner: ChatReadCountOwner, onEvent: @escaping @MainActor (ChatReadCountEvent) -> Void) { handler = onEvent }
    func close() { handler = nil }
    func emit(_ event: ChatReadCountEvent) { handler?(event) }
}
@MainActor final class SDKChatClient {
    init(validSession: @escaping @MainActor (ChatContext) -> Bool) {}
}
@MainActor final class ChatStore {
    var context: ChatContext?
    var onMessageUnavailable: ((ChatMessageRecord?, ChatContext) -> Void)?
    var closeCount = 0
    init(client: SDKChatClient) {}
    func close() { closeCount += 1; context = nil }
    func removeSenderMessages(_ ids: Set<String>) {}
    func isMessageDeleted(_ message: ChatMessageRecord) -> Bool { false }
    func applyMemberMetadata(_ members: [ChatGroupMember], context: ChatContext) {}
}
@MainActor final class SDKChatMediaClient {}
@MainActor final class ChatMediaStore {
    init(client: SDKChatMediaClient) {}
    func cancel() {}
}
@MainActor final class ChatVoiceRecorder { func cancel() {} }
@MainActor final class ChatMediaPreviewStore {
    static func clearCache(context: ChatContext) throws {}
    func close() {}
    func invalidateMessage(_ message: ChatMessageRecord?, context: ChatContext) {}
    func invalidateDeletedMessages(_ ids: Set<String>, context: ChatContext) {}
}
@MainActor final class SDKChatSettingsClient: ChatSettingsClient {
    func load(context: ChatContext) async throws -> ChatSettingsSnapshot { ChatSettingsSnapshot(isPinned: false, isMuted: false, canClear: false, group: nil) }
    func setConversation(context: ChatContext, pinned: Bool?, muted: Bool?) async throws {}
    func clear(context: ChatContext) async throws {}
    func groupAction(_ action: ChatGroupAction, context: ChatContext) async throws {}
    func close() {}
}

@main struct RuntimeDepartureChecks {
    /// 群退出关闭当前聊天；同ID旧认证回执不能影响重新登录的聊天。
    @MainActor static func main() {
        let runtime = ChatRuntime.shared
        runtime.activate(userUID: "member", tenantID: "club", sessionID: UUID())
        let group = ChatRoute(id: "group", kind: .group, title: "测试群", avatarURL: "")
        let other = ChatRoute(id: "other", kind: .group, title: "其他群", avatarURL: "")
        let oldContext = runtime.context(for: group)!
        let groupStore = runtime.makeStore(); groupStore.context = oldContext
        let otherStore = runtime.makeStore(); otherStore.context = runtime.context(for: other)
        let owner = ChatVoiceRecorder(); var cleanupCount = 0
        runtime.registerCleanup(owner: owner, conversationID: group.id) { cleanupCount += 1 }
        runtime.closeConversation(context: oldContext)
        precondition(runtime.closedConversationContext == oldContext, "离群受理发布当前会话和认证轮次供导航返回")
        precondition(groupStore.context == nil && groupStore.closeCount == 1, "离群关闭指定聊天")
        precondition(otherStore.context != nil && otherStore.closeCount == 0, "离群不关闭其它群聊天")
        precondition(cleanupCount == 1 && runtime.contentRevision(oldContext) != nil, "离群取消当前媒体并隔离之前的历史回读")
        runtime.reportConversationCleanupFailure(context: oldContext)
        precondition(runtime.conversationCleanupWarning?.contains("已受理") == true, "后续清理失败明确保留离群成功语义")
        runtime.activate(userUID: "member", tenantID: "club", sessionID: UUID())
        let newContext = runtime.context(for: group)!
        let newStore = runtime.makeStore(); newStore.context = newContext
        runtime.closeConversation(context: oldContext)
        runtime.reportConversationCleanupFailure(context: oldContext)
        precondition(runtime.closedConversationContext == nil && runtime.conversationCleanupWarning == nil && newStore.context == newContext, "同UID同群旧轮次不能关闭新聊天或提示旧清理失败")
        runtime.closeConversation(context: newContext)
        precondition(runtime.closedConversationContext == newContext && newStore.context == nil, "新轮次有效关闭仍可执行")
        runtime.close()
        precondition(runtime.closedConversationContext == nil && runtime.conversationCleanupWarning == nil, "退出账号清除旧会话导航与反馈")
        print("Runtime departure checks: 8 passed")
    }
}
