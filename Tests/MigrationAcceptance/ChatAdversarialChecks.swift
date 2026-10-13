//
//  ChatAdversarialChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

@MainActor final class AcceptanceChatClient: ChatClient {
    var callback: ((ChatEvent) -> Void)?
    var page = ChatPage(messages: [], hasMore: false)
    var policy = ChatPermission()
    var sent: [ChatMessageRecord] = []
    var operations: [ChatMessageAction] = []
    var suspendHistory = false
    var waiting: CheckedContinuation<ChatPage, Error>?
    var requests: [(String?, Int)] = []
    /// 用真实Store读取可控缓存，不连接生产服务器。
    func cached(context: ChatContext, offset: Int) throws -> [ChatMessageRecord] { page.messages }
    /// 记录游标并支持迟到补页，验证退出和同账号重新登录。
    func history(context: ChatContext, before: String?, offset: Int) async throws -> ChatPage {
        requests.append((before, offset))
        if suspendHistory { return try await withCheckedThrowingContinuation { waiting = $0 } }
        return page
    }
    /// 保留代理闭包，独立验证旧回调失效。
    func observe(context: ChatContext, onEvent: @escaping @MainActor (ChatEvent) -> Void) { callback = onEvent }
    /// 保留已提交请求以模拟服务器不支持取消的情形。
    func stop() {}
    /// 收集发包次数，避免重复重发被成功输出掩盖。
    func send(_ message: ChatMessageRecord, context: ChatContext) throws { sent.append(message) }
    /// 模拟页面打开后的动态禁言和权限收回。
    func permissions(context: ChatContext) throws -> ChatPermission { policy }
    /// 离线读回执只返回，不伪造服务器读计数。
    func read(_ messages: [ChatMessageRecord], context: ChatContext) async throws {}
    /// 操作成功由测试明确注入，用于验证业务状态机。
    func perform(_ action: ChatMessageAction, message: ChatMessageRecord, context: ChatContext) async throws { operations.append(action) }
}

@main struct ChatAdversarialChecks {
    @MainActor static var failures = 0
    @MainActor static var checks = 0
    /// 逐项验证生产逻辑，每项失败仍继续收集可复现缺陷。
    @MainActor static func main() async {
        var recalled = message("recalled", server: "s1"); recalled.status = .recalled
        check(ChatMessageMerge.merge([recalled], with: [message("recalled", server: "s1")]).first?.status == .recalled, "CHAT-022 撤回不得被旧补页复活")
        var deleted = message("deleted", server: "s2"); deleted.status = .deleted
        let afterDelete = ChatMessageMerge.merge([], with: [deleted])
        check(ChatMessageMerge.merge(afterDelete, with: [message("deleted", server: "s2")]).filter { $0.status == .normal }.isEmpty, "CHAT-021 删除墓碑必须阻止历史复活")
        var ack = message("sent", server: "s3"); ack.timestamp = 900; ack.text = "新版本"
        var stale = ack; stale.timestamp = 100; stale.text = "旧版本"
        let merged = ChatMessageMerge.merge([ack], with: [stale])
        check(merged.first?.timestamp == 900, "CHAT-005 旧补页不能回退ACK服务时间")
        check(merged.first?.text == "新版本", "CHAT-023 旧补页不能回退已编辑正文")
        var zero = ChatPermission(); zero.canRecall = true; zero.canEdit = true; zero.recallWindow = 0; zero.editWindow = 0
        check(!ChatActionPolicy.allowed(for: message("own", server: "s4", sender: "me"), userUID: "me", permission: zero, now: 1000).contains(.recall), "CHAT-022 撤回窗口0必须关闭")
        check(!ChatActionPolicy.allowed(for: message("own", server: "s4", sender: "me"), userUID: "me", permission: zero, now: 1000).contains(.edit), "CHAT-023 编辑窗口0必须关闭")
        zero.canSend = false; zero.editWindow = 100
        check(!ChatActionPolicy.allowed(for: message("own", server: "s4", sender: "me"), userUID: "me", permission: zero, now: 1000).contains(.edit), "CHAT-018 禁言必须禁编辑")
        let client = AcceptanceChatClient(); client.policy.canDelete = true
        let store = ChatStore(client: client)
        let route = ChatRoute(id: "peer", kind: .single, title: "验收好友", avatarURL: "")
        let context = ChatContext(userUID: "me", tenantID: "test-tenant", sessionID: UUID(), route: route)
        client.page = ChatPage(messages: (0..<100).map { message("m\($0)", server: "s\($0)", time: Int64($0)) }, hasMore: true)
        await store.open(context)
        check(store.messages.count == 100, "CHAT-002 首屏100条")
        client.page = ChatPage(messages: [message("overlap", server: "s0"), message("older", server: "old", time: -1)], hasMore: false)
        await store.loadMore()
        check(store.messages.count == 101 && client.requests.last?.0 == "s0", "CHAT-002 100边界交叠双ID去重与服务游标")
        for item in store.messages { store.toggleSelection(item.id) }
        check(store.selectedIDs.count == 100, "CHAT-024 多选最多100条")
        store.cancelSelection(); check(store.selectedIDs.isEmpty, "CHAT-024 取消不操作消息")
        await store.perform(.delete, id: "m1")
        client.callback?(.upsert(message("m1", server: "s1", time: 1)))
        check(!store.messages.contains(where: { $0.localID == "m1" }), "CHAT-021 删除操作完成后迟到正文不能复活")
        store.input = "验收标记🙂"; store.sendText()
        let local = client.sent.last!.localID
        client.callback?(.ack(localID: local, serverID: "", timestamp: 10))
        check(store.messages.first(where: { $0.localID == local })?.state == .sending, "CHAT-005 无服务IDACK不能成功")
        client.callback?(.ack(localID: local, serverID: "ack", timestamp: 500))
        client.callback?(.ack(localID: local, serverID: "ack", timestamp: 500))
        client.callback?(.failed(localID: local, reason: .timeout))
        check(store.messages.filter { $0.serverID == "ack" }.count == 1 && store.messages.first(where: { $0.localID == local })?.state == .sent, "CHAT-004 ACK重复及迟到失败去重")
        let oldCallback = client.callback
        client.suspendHistory = true
        let reopening = ChatContext(userUID: "me", tenantID: "test-tenant", sessionID: UUID(), route: route)
        let task = Task { await store.open(reopening) }
        while client.waiting == nil { await Task.yield() }
        let newContext = ChatContext(userUID: "me", tenantID: "other-tenant", sessionID: UUID(), route: route)
        client.suspendHistory = false; client.page = ChatPage(messages: [], hasMore: false)
        await store.open(newContext)
        client.waiting?.resume(returning: ChatPage(messages: [message("late", server: "late")], hasMore: false)); await task.value
        oldCallback?(.upsert(message("oldCallback", server: "oldCallback")))
        check(store.context == newContext && store.messages.isEmpty, "CHAT-049 同UID换租户旧历史旧代理隔离")
        check(store.errorMessage == nil, "CHAT-049 换租户不遗留上一会话错误提示")
        print("Independent Chat Acceptance: \(checks - failures)/\(checks) passed; \(failures) failed")
        if failures > 0 { exit(1) }
    }
    /// 构造匿名离线身份，数据不含用户凭据。
    static func message(_ local: String, server: String, sender: String = "peer", time: Int64 = 100) -> ChatMessageRecord {
        ChatMessageRecord(localID: local, serverID: server, conversationID: "peer", senderID: sender, senderName: "验收对象", text: "验收正文", timestamp: time, state: .sent)
    }
    /// 清楚打印断言结果，避免静态检查冒充业务通过。
    @MainActor static func check(_ result: Bool, _ label: String) {
        checks += 1; if !result { failures += 1 }; print("\(result ? "PASS" : "FAIL") \(label)")
    }
}
