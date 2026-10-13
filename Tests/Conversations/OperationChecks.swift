import Foundation

@MainActor
private final class OperationClient: ConversationsClient, ConversationOperationsClient {
    var records: [ConversationRecord] = []
    var operations = 0
    var continuation: CheckedContinuation<Void, Error>?
    /// 保存事件订阅，测试通过读库结果验证操作。
    func observe(for userUID: String, _ onChange: @escaping @MainActor (ConversationsChange) -> Void) {}
    /// 测试客户端无需释放外部资源。
    func stopObserving() {}
    /// 返回指定的真实形状快照。
    func loadConversations(for userUID: String) async throws -> [ConversationRecord] { records }
    /// 人为暂停请求以验证重复操作和退出边界。
    func perform(_ action: ConversationAction, conversation: ConversationRecord, userUID: String) async throws {
        operations += 1
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
}

@main
private struct OperationChecks {
    /// 构造单聊、群聊和助手快照。
    static func record(_ id: String, kind: ConversationKind = .single) -> ConversationRecord {
        ConversationRecord(id: id, title: id, avatarURL: "", kind: kind, preview: "hi", latestTime: nil,
                           unreadCount: 0, isMarkedUnread: false, isPinned: false, isMuted: false, isDraft: false)
    }
    /// 检验禁用入口、去重和旧会话完成不得污染新账号。
    @MainActor static func main() async {
        precondition(ConversationActionPolicy.allowed(for: record("100002")) == [.togglePin, .delete])
        precondition(ConversationActionPolicy.allowed(for: record("system", kind: .systemMessage)).isEmpty)
        let client = OperationClient()
        client.records = [record("friend")]
        let store = ConversationsStore(client: client)
        store.prepare(for: "A")
        await store.reload()
        let first = Task { await store.perform(.togglePin, conversationID: "friend") }
        while client.continuation == nil { await Task.yield() }
        await store.perform(.toggleMute, conversationID: "friend")
        precondition(client.operations == 1, "同会话操作不能并发重复提交")
        store.prepare(for: "B")
        client.records = []
        await store.reload()
        client.continuation?.resume(throwing: NSError(domain: "old", code: 1))
        await first.value
        precondition(store.operationError == nil && store.busyConversationIDs.isEmpty)
        precondition(store.conversations.isEmpty, "旧请求失败不能污染新用户")
        print("Conversation operations checks passed")
    }
}
