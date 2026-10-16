import Foundation
import Combine

@MainActor final class SuspendedChatClient: ChatClient {
    var callback: ((ChatEvent) -> Void)?
    var waiting: CheckedContinuation<ChatPage, Error>?
    var page = ChatPage(messages: [], hasMore: false)
    var suspend = false
    var sent: [ChatMessageRecord] = []
    var playedGames: [ChatMessageRecord] = []
    func markGameAnimationPlayed(_ message: ChatMessageRecord, context: ChatContext) throws { playedGames.append(message) }
    var readBatches: [[ChatMessageRecord]] = []
    var suspendReads = false
    var readWaiting: CheckedContinuation<Void, Never>?
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
    /// 已读可暂停回执，验证清历史后的旧结果不能重新合并消息。
    func read(_ messages: [ChatMessageRecord], context: ChatContext) async throws {
        readBatches.append(messages)
        if suspendReads { await withCheckedContinuation { readWaiting = $0 } }
    }
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
        client.callback?(.pinsChanged)
        expect(store.pinRevision == 1 && store.messages.count == 1, "置顶刷新事件无正文变化仍通知列表回读")
        let old = client.callback
        client.callback?(.upsert(message("secondLocal", server: "11")))
        expect(store.messages.count == 1, "服务器ID与本地ID交叠去重")
        store.input = "你好🙂"
        store.sendText()
        expect(store.messages.count == 2 && client.sent.count == 1, "发送真实入队并保持发送中")
        let local = client.sent[0].localID
        client.callback?(.ack(localID: local, serverID: "12", timestamp: 300))
        client.callback?(.failed(localID: local, reason: .timeout))
        expect(store.messages.last?.state == .sent && store.errorMessage == nil, "迟到失败不能覆盖有效ACK或触发失败提示")
        client.policy.canUpload = true
        var preview = ChatMessageRecord(localID: "photo-preview", conversationID: context.route.id,
            senderID: context.userUID, senderName: "我", type: 1, timestamp: 500)
        preview.localMediaPreviewURL = URL(fileURLWithPath: "/tmp/photo.jpg")
        preview.isMediaUploading = true
        try? store.beginMediaUpload(preview)
        expect(store.messages.first(where: { $0.localID == preview.localID })?.isMediaUploading == true,
               "图片上传前先插入本地预览")
        var uploaded = preview; uploaded.localMediaPreviewURL = nil; uploaded.isMediaUploading = false
        uploaded.resource = "/remote/photo"; uploaded.thumbnail = "/remote/thumb"
        try? store.sendAttachment(uploaded)
        expect(store.messages.filter { $0.localID == preview.localID }.count == 1 &&
               store.messages.first(where: { $0.localID == preview.localID })?.resource == "/remote/photo",
               "上传完成沿用原消息身份")
        store.discardMediaUpload(preview.localID)
        expect(store.messages.contains(where: { $0.localID == preview.localID }), "迟到取消不能删除SDK队列消息")
        var cancelledPreview = preview; cancelledPreview.localID = "cancelled-preview"
        try? store.beginMediaUpload(cancelledPreview)
        store.discardMediaUpload(cancelledPreview.localID)
        expect(!store.messages.contains(where: { $0.localID == cancelledPreview.localID }), "取消仅清理上传中占位")
        client.policy.canSend = false
        var rejectedPreview = preview; rejectedPreview.localID = "rejected-preview"
        do { try store.beginMediaUpload(rejectedPreview); fatalError("禁言后不可展示上传占位") }
        catch { expect(!store.messages.contains(where: { $0.localID == rejectedPreview.localID }), "权限拒绝不插入占位") }
        store.input = "不应发送"
        store.sendText()
        expect(client.sent.count == 2 && store.input == "不应发送", "提交复核动态禁言并保留输入")
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
        var readPublications = 0
        let readObservation = store.$messages.dropFirst().sink { _ in readPublications += 1 }
        await store.flushVisibleReads()
        expect(readPublications == 1, "一批可见已读只发布一次消息快照")
        readObservation.cancel()
        expect(client.readBatches.count == 1 && Set(client.readBatches[0].map(\.serverID)) == ["r1", "r2"], "正文两秒批次排除未播放语音")
        store.isVisible = false; await store.markVisible("voice", voicePlayed: true)
        expect(client.readBatches.count == 2 && client.readBatches[1][0].serverID == "v", "详情播放才上报语音已读")
        store.close(); await store.open(context); store.isVisible = true; store.isForeground = false
        await store.markVisible("r1"); await store.flushVisibleReads()
        expect(client.readBatches.count == 2, "后台不能发送已读批次")
        // 前台恢复时几何可以完全不变，仍须重新上报可见未读正文。
        store.setVisibleMessageIDs(["r1", "voice"])
        store.isForeground = true
        await Task.yield(); await store.flushVisibleReads()
        expect(client.readBatches.count == 3 && client.readBatches[2].map(\.serverID) == ["r1"], "恢复前台重读可见正文，排除未播放语音和屏外消息")
        store.isVisible = false; store.setVisibleMessageIDs(["r2"])
        await Task.yield(); await store.flushVisibleReads()
        expect(client.readBatches.count == 3, "被覆盖页面恢复方法不能提前上报")
        store.isVisible = true
        await Task.yield(); await store.flushVisibleReads()
        expect(client.readBatches.count == 4 && client.readBatches[3].map(\.serverID) == ["r2"], "返回聊天时几何不变仍会重读可见未读正文")
        store.close()
        await store.open(context); store.setVisibleMessageIDs(["r1"])
        await store.markVisible("r1")
        client.callback?(.cleared); await store.flushVisibleReads()
        expect(client.readBatches.count == 4, "清历史必须取消尚未发送的旧已读队列")
        expect(store.messages.isEmpty, "清历史后的读批次不能复活旧正文")
        store.close(); await store.open(context); store.setVisibleMessageIDs(["r1"])
        await store.markVisible("r1"); client.suspendReads = true
        let pendingRead = Task { await store.flushVisibleReads() }
        while client.readWaiting == nil { await Task.yield() }
        client.callback?(.cleared); client.readWaiting?.resume(); client.readWaiting = nil
        await pendingRead.value
        expect(store.messages.isEmpty, "已发送批次迟到成功不能复活已清正文")
        store.close(); await store.open(context)
        let pendingVoice = Task { await store.markVisible("voice", voicePlayed: true) }
        while client.readWaiting == nil { await Task.yield() }
        client.callback?(.cleared); client.readWaiting?.resume(); client.readWaiting = nil
        await pendingVoice.value
        expect(store.messages.isEmpty, "语音已读迟到成功不能复活已清附件")
        client.suspendReads = false; store.close()
        client.policy.canDelete = true; client.page = ChatPage(messages: [message("d1", server: "d1"), message("d2", server: "d2")], hasMore: false)
        store.isForeground = true; await store.open(context); store.toggleSelection("d1"); store.toggleSelection("d2"); client.rejectedIDs = ["d2"]
        await store.deleteSelected(both: false)
        expect(store.messages.map(\.id) == ["d2"] && store.selectedIDs == ["d2"] && store.errorMessage?.contains("1条未删除") == true, "部分删除失败保留选择及逐条明细")
        client.policy.canSend = true; client.policy.canUpload = false; client.policy.canUploadFile = true
        var file = message("file", server: "file", type: 5); file.state = .failed; client.callback?(.upsert(file))
        let priorSent = client.sent.count; store.retry("file")
        expect(client.sent.count == priorSent + 1, "文件重发使用upFile而非图片视频权限")
        client.callback?(.failed(localID: "file", reason: .timeout))
        expect(store.messages.first(where: { $0.localID == "file" })?.state == .failed && store.errorMessage == ChatFailureReason.timeout.message, "实时发送失败保留重试状态并提供Toast文案")
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
        // 成员历史事件也会推进清理轮次，旧批次结束后必须释放自己的pending资格。
        let interruptedClient = SuspendedChatClient()
        interruptedClient.page = ChatPage(messages: [message("pending", server: "pending")], hasMore: false)
        let interruptedStore = ChatStore(client: interruptedClient)
        await interruptedStore.open(context); interruptedStore.setVisibleMessageIDs(["pending"])
        await interruptedStore.markVisible("pending"); interruptedClient.suspendReads = true
        let interruptedRead = Task { await interruptedStore.flushVisibleReads() }
        while interruptedClient.readWaiting == nil { await Task.yield() }
        interruptedClient.callback?(.memberHistoryDeleted(["anotherAuthor"]))
        interruptedClient.readWaiting?.resume(); interruptedClient.readWaiting = nil
        await interruptedRead.value; interruptedClient.suspendReads = false
        await interruptedStore.markVisible("pending"); await interruptedStore.flushVisibleReads()
        expect(interruptedClient.readBatches.count == 2 && interruptedStore.messages.first?.isRead == true, "成员历史变化后的旧读批次不能永久阻止可见正文重读")
        interruptedStore.close()
        interruptedClient.page = ChatPage(messages: [message("voicePending", server: "voicePending", type: 4)], hasMore: false)
        await interruptedStore.open(context); interruptedClient.suspendReads = true
        let interruptedVoice = Task { await interruptedStore.markVisible("voicePending", voicePlayed: true) }
        while interruptedClient.readWaiting == nil { await Task.yield() }
        interruptedClient.callback?(.memberHistoryDeleted(["anotherAuthor"]))
        interruptedClient.readWaiting?.resume(); interruptedClient.readWaiting = nil
        await interruptedVoice.value; interruptedClient.suspendReads = false
        await interruptedStore.markVisible("voicePending", voicePlayed: true)
        expect(interruptedClient.readBatches.count == 4 && interruptedStore.messages.first?.isRead == true, "成员历史变化后的旧语音读回执必须释放重播资格")
        interruptedStore.close()
        // 在群草稿中间选择成员，显示、UID与发送正文必须保持一致。
        let mentionClient = SuspendedChatClient()
        let mentionStore = ChatStore(client: mentionClient)
        let groupContext = ChatContext(userUID: "me", tenantID: "club", sessionID: UUID(), route: ChatRoute(id: "group", kind: .group, title: "测试群", avatarURL: ""))
        await mentionStore.open(groupContext)
        let member = ChatGroupMember(id: "peer-uid", name: "测试成员", avatar: "", role: 0, isDeleted: false)
        mentionStore.input = "[微笑]前@后🙂"; mentionStore.reconcileMentions()
        let caret = mentionStore.insertMention(member, replacingAt: NSRange(location: 5, length: 1))
        expect(mentionStore.input == "[微笑]前@测试成员 后🙂" && caret?.location == 11, "光标处选择成员保留表情、后文和Unicode")
        expect(mentionStore.mentions.first?.userUID == member.id && mentionStore.mentions.first?.location == 5, "中间插入成员绑定真实UID")
        mentionStore.sendText()
        expect(mentionClient.sent.last?.type == 10 && mentionClient.sent.last?.mentions.first?.userUID == member.id, "提及正文沿现有type10发送并保留UID")
        mentionStore.input = "@后文"; mentionStore.reconcileMentions()
        mentionClient.policy.isPrivateChat = true
        mentionClient.callback?(.permissionsChanged)
        expect(mentionStore.insertMention(member, replacingAt: NSRange(location: 0, length: 1)) == nil && mentionStore.input == "@后文", "普通成员受限时保留普通@不添加UID")
        mentionStore.close()
        expect(mentionStore.insertMention(member, replacingAt: NSRange(location: 0, length: 1)) == nil, "关闭会话后拒绝迟到成员选择")
        let gameClient = SuspendedChatClient(); let gameStore = ChatStore(client: gameClient)
        await gameStore.open(groupContext)
        gameStore.input = "保留草稿🙂"; gameStore.reference = message("reference-game", server: "reference-game")
        for kind in ChatGameSticker.allCases {
            gameStore.sendGame(kind)
            guard let sent = gameClient.sent.last else { fatalError("游戏未进入发送队列") }
            expect(sent.type == 21 && sent.gameType == kind.rawValue && kind.isValid(sent.text) && sent.referenceID.isEmpty, "默认游戏使用旧type21和一次生成的有效结果")
            expect(gameStore.input == "保留草稿🙂" && gameStore.reference != nil, "游戏发送不清除文字草稿和引用")
            gameStore.completeGameAnimation(sent)
            expect(gameClient.playedGames.last?.id == sent.id && gameStore.messages.first(where: { $0.id == sent.id })?.gameAnimationPlayed == true, "动画完成回写当前原条")
            gameClient.callback?(.failed(localID: sent.localID, reason: .timeout))
            gameStore.retry(sent.localID)
            expect(gameClient.sent.last?.id == sent.id && kind.isValid(gameClient.sent.last?.text ?? "") && gameClient.sent.last?.gameType == kind.rawValue, "失败游戏沿旧端重试并保留消息身份及有效结果")
        }
        let sentGames = gameClient.sent.count
        gameClient.policy.canSend = false; gameClient.callback?(.permissionsChanged)
        gameStore.sendGame(.dice)
        expect(gameClient.sent.count == sentGames && gameStore.input == "保留草稿🙂", "禁言不得发送游戏或清草稿")
        gameStore.close()
        print("Chat checks: existing regression, cursor mentions and game sending passed")
    }
    /// 构造含双ID的普通消息。
    static func message(_ id: String, server: String, type: Int = 0) -> ChatMessageRecord {
        ChatMessageRecord(localID: id, serverID: server, conversationID: "peer", senderID: "peer", senderName: "好友", type: type, text: "正文", timestamp: 100, state: .sent)
    }
    /// 失败立即终止脚本，防止仅打印成功。
    static func expect(_ value: @autoclosure () -> Bool, _ name: String) { if !value() { fatalError(name) } }
}
