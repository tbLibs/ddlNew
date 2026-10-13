import Foundation

@MainActor final class SuspendedChatClient: ChatClient {
    var callback: ((ChatEvent) -> Void)?
    var waiting: CheckedContinuation<ChatPage, Error>?
    var page = ChatPage(messages: [], hasMore: false)
    var suspend = false
    var sent: [ChatMessageRecord] = []
    var readBatches: [[ChatMessageRecord]] = []
    var rejectedIDs: Set<String> = []
    var policy = ChatPermission()
    /// 注入可暂停历史请求，让切账号后旧结果仍能返回。
    func history(context: ChatContext, before: String?, offset: Int) async throws -> ChatPage {
        if suspend { return try await withCheckedThrowingContinuation { waiting = $0 } }
        return page
    }
    /// 缓存读取使用同一页数据，模拟离线已有历史。
    func cached(context: ChatContext, offset: Int) throws -> [ChatMessageRecord] { page.messages }
    /// 保留旧回调以验证失效代理。
    func observe(context: ChatContext, onEvent: @escaping @MainActor (ChatEvent) -> Void) { callback = onEvent }
    /// 测试客户端允许旧代理迟到。
    func stop() {}
    /// 收集消息供回执错序测试。
    func send(_ message: ChatMessageRecord, context: ChatContext) throws { sent.append(message) }
    /// 权限读取可模拟开页后禁言。
    func permissions(context: ChatContext) throws -> ChatPermission { policy }
    /// 已读测试不伪造群计数。
    func read(_ messages: [ChatMessageRecord], context: ChatContext) async throws { readBatches.append(messages) }
    /// 测试动作以注入错误替代外部服务。
    func perform(_ action: ChatMessageAction, message: ChatMessageRecord, context: ChatContext) async throws { if rejectedIDs.contains(message.id) { throw ChatClientError.unavailable("拒绝删除") } }
}

@main struct ChatChecks {
    /// 顺序执行真实Store行为与隔离边界。
    @MainActor static func main() async {
        let client = SuspendedChatClient()
        let context = ChatContext(userUID: "me", tenantID: "club", sessionID: UUID(), route: ChatRoute(id: "peer", kind: .single, title: "好友", avatarURL: ""))
        let store = ChatStore(client: client)
        client.page = ChatPage(messages: [message("one", server: "11")], hasMore: true)
        await store.open(context)
        expect(store.messages.count == 1, "离线缓存可见")
        let old = client.callback
        client.callback?(.upsert(message("secondLocal", server: "11")))
        expect(store.messages.count == 1, "服务器ID与本地ID交叠去重")
        store.input = "你好🙂"
        store.sendText()
        expect(store.messages.count == 2 && client.sent.count == 1, "发送真实入队并保持发送中")
        let local = client.sent[0].localID
        client.callback?(.ack(localID: local, serverID: "12", timestamp: 300))
        client.callback?(.failed(localID: local, reason: .timeout))
        expect(store.messages.last?.state == .sent, "迟到失败不能覆盖有效ACK")
        client.policy.canSend = false
        store.input = "不应发送"
        store.sendText()
        expect(client.sent.count == 1 && store.input == "不应发送", "提交复核动态禁言并保留输入")
        client.suspend = true
        let task = Task { await store.loadMore() }
        await Task.yield()
        store.close()
        client.waiting?.resume(returning: ChatPage(messages: [message("late", server: "100")], hasMore: false))
        await task.value
        old?(.upsert(message("old", server: "99")))
        expect(store.messages.isEmpty, "退出后的历史与代理迟到隔离")
        var records = [message("a", server: "1"), message("b", server: "2")]
        records[0].status = .recalled
        records = ChatMessageMerge.merge(records, with: [message("a", server: "1")])
        expect(records[0].status == .recalled, "历史不能复活撤回原文")
        expect(!ChatActionPolicy.allowed(for: message("x", server: "3", type: 18), userUID: "me", permission: ChatPermission()).contains(.forward), "合并记录不可再次转发")
        if case .ack(let acknowledgedID, _, _)? = ChatACKNormalizer.event(envelopeID: "envelope", acknowledgedID: "original", serverID: "server", timestamp: 100) {
            expect(acknowledgedID == "original", "ACK必须对应ackMsgId而非信封msgId")
        } else { fatalError("有效ACK未返回") }
        expect(ChatACKNormalizer.event(envelopeID: "envelope", acknowledgedID: "", serverID: "server", timestamp: 100) == nil, "空原消息ID不能产生成功")
        client.suspend = false; await store.open(context)
        client.suspend = true
        let clearingHistory = Task { await store.loadMore() }; await Task.yield()
        client.callback?(.cleared)
        client.waiting?.resume(returning: ChatPage(messages: [message("preclear", server: "5")], hasMore: false))
        await clearingHistory.value
        expect(store.messages.isEmpty, "清空前开始的历史不能在清空后复活")
        client.suspend = false; store.close()
        client.page = ChatPage(messages: [message("r1", server: "r1"), message("r2", server: "r2"), message("voice", server: "v", type: 4)], hasMore: false)
        await store.open(context); store.setVisibleMessageIDs(["r1", "r2", "voice"])
        await store.markVisible("r1"); await store.markVisible("r2"); await store.markVisible("voice")
        expect(client.readBatches.isEmpty, "可见回调不能立即逐条已读")
        await store.flushVisibleReads()
        expect(client.readBatches.count == 1 && Set(client.readBatches[0].map(\.serverID)) == ["r1", "r2"], "正文两秒批次排除未播放语音")
        store.isVisible = false; await store.markVisible("voice", voicePlayed: true)
        expect(client.readBatches.count == 2 && client.readBatches[1][0].serverID == "v", "详情播放才上报语音已读")
        store.close(); await store.open(context); store.isVisible = true; store.isForeground = false
        await store.markVisible("r1"); await store.flushVisibleReads()
        expect(client.readBatches.count == 2, "后台不能发送已读批次")
        store.close()
        client.policy.canDelete = true; client.page = ChatPage(messages: [message("d1", server: "d1"), message("d2", server: "d2")], hasMore: false)
        store.isForeground = true; await store.open(context); store.toggleSelection("d1"); store.toggleSelection("d2"); client.rejectedIDs = ["d2"]
        await store.deleteSelected(both: false)
        expect(store.messages.map(\.id) == ["d2"] && store.selectedIDs == ["d2"] && store.errorMessage?.contains("1条未删除") == true, "部分删除失败保留选择及逐条明细")
        client.policy.canSend = true; client.policy.canUpload = false; client.policy.canUploadFile = true
        var file = message("file", server: "file", type: 5); file.state = .failed; client.callback?(.upsert(file))
        let priorSent = client.sent.count; store.retry("file")
        expect(client.sent.count == priorSent + 1, "文件重发使用upFile而非图片视频权限")
        store.close()
        client.suspend = false
        var edited = message("metadata", server: "metadata"); edited.text = "已经编辑的正文"; edited.timestamp = 900; edited.isRead = true; edited.readCount = 3
        client.page = ChatPage(messages: [edited], hasMore: true); await store.open(context); store.reference = edited
        client.callback?(.memberMetadataChanged([ChatGroupMember(id: "peer", name: "新群昵称", avatar: "new", role: 1, isDeleted: false)]))
        expect(store.messages.first?.senderName == "新群昵称" && store.messages.first?.text == "已经编辑的正文" && store.messages.first?.timestamp == 900 && store.messages.first?.readCount == 3, "群昵称刷新仅替换作者元数据，不回退编辑ACK已读")
        store.toggleSelection("metadata"); client.suspend = true
        let pendingMemberHistory = Task { await store.loadMore() }; await Task.yield()
        client.callback?(.memberHistoryDeleted(["peer"]))
        client.waiting?.resume(returning: ChatPage(messages: [edited], hasMore: false)); await pendingMemberHistory.value
        expect(store.messages.isEmpty && store.selectedIDs.isEmpty && store.referenceSummary("metadata") == "原消息已删除", "他端删除成员历史同步气泡、选择、引用并阻止迟到页复活")
        expect(store.isMessageDeleted(edited), "媒体重试可以识别已经删除的原条墓碑")
        client.callback?(.memberMetadataChanged([ChatGroupMember(id: "peer", name: "再改昵称", avatar: "", role: 0, isDeleted: false)]))
        expect(store.messages.isEmpty, "昵称刷新不能复活成员历史墓碑")
        store.close()
        var unavailable: [String] = []
        store.onMessageUnavailable = { item, _ in unavailable.append(item?.id ?? "all") }
        client.suspend = false; client.page = ChatPage(messages: [edited], hasMore: false)
        await store.open(context)
        edited.status = .recalled; client.callback?(.upsert(edited))
        expect(unavailable.contains("metadata") && store.isMessageDeleted(edited), "撤回原条必须让已打开附件失效并拒绝重试")
        client.callback?(.cleared)
        expect(unavailable.last == "all", "清空事件必须通知全部已打开附件")
        store.close()
        print("Chat checks: 23 passed")
    }
    /// 构造含双ID的普通消息。
    static func message(_ id: String, server: String, type: Int = 0) -> ChatMessageRecord {
        ChatMessageRecord(localID: id, serverID: server, conversationID: "peer", senderID: "peer", senderName: "好友", type: type, text: "正文", timestamp: 100, state: .sent)
    }
    /// 失败立即终止脚本，防止仅打印成功。
    static func expect(_ value: @autoclosure () -> Bool, _ name: String) { if !value() { fatalError(name) } }
}
