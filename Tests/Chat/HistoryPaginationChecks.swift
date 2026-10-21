//
//  HistoryPaginationChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/21.
//

import Foundation

// 只替代SDK数据库和运输边界，历史请求、缓存回读与ChatStore均运行生产方法。
struct HistorySendType { var rawValue: Int = 1 }
final class NoaIMChatMessageModel {
    var record: ChatMessageRecord
    var backDelServiceMsgID: String?
    var messageStatus: Int { get { record.status.rawValue } set { record.status = ChatMessageStatus(rawValue: newValue)! } }
    var chatMessageReaded: Bool { get { record.isRead } set { record.isRead = newValue } }
    var haveReadCount: Int { get { record.readCount } set { record.readCount = newValue } }
    var totalNeedReadCount: Int { get { record.totalReadCount } set { record.totalReadCount = newValue } }
    var msgID: String { get { record.localID } set { record.localID = newValue } }
    var sendTime: Int64 { get { record.timestamp } set { record.timestamp = newValue } }
    var messageSendType = HistorySendType()
    init(_ record: ChatMessageRecord) { self.record = record }
}
enum SDKChatMessageMapper {
    static func record(_ model: NoaIMChatMessageModel, userUID: String) -> ChatMessageRecord { model.record }
    static func historyModel(_ row: [String: Any], context: ChatContext) -> NoaIMChatMessageModel {
        NoaIMChatMessageModel(row["record"] as! ChatMessageRecord)
    }
}
typealias LingIMSuccessCallback = ([String: Any], String?) -> Void
typealias LingIMFailureCallback = (Int, String?, String?) -> Void
@MainActor final class HistoryDatabase: NSObject {
    var records: [ChatMessageRecord] = []
    var remote: [ChatMessageRecord] = []
    var limit = 100
    var fails = false
    var malformed = false
    var suspend = false
    var pending: LingIMSuccessCallback?
    var requests: [[String: Any]] = []
    var kinds: [String] = []
    func toolGetChatMessageHistory(with id: String, offset: Int) -> Any {
        records.filter { $0.conversationID == id && $0.status == .normal }
            .sorted { $0.timestamp > $1.timestamp }.dropFirst(offset).prefix(100).reversed().map(NoaIMChatMessageModel.init)
    }
    func toolGetChatMessageHistoryIncludingInactive(with id: String, offset: Int) -> Any {
        records.filter { $0.conversationID == id }.sorted { $0.timestamp > $1.timestamp }
            .dropFirst(offset).prefix(100).map(NoaIMChatMessageModel.init)
    }
    func toolGetOneChatMessage(withServiceMessageID id: String, sessionID: String) -> NoaIMChatMessageModel? {
        records.first { $0.serverID == id && $0.conversationID == sessionID }.map(NoaIMChatMessageModel.init)
    }
    func toolGetOneChatMessage(withMessageID id: String, sessionID: String) -> NoaIMChatMessageModel? {
        records.first { $0.localID == id && $0.conversationID == sessionID }.map(NoaIMChatMessageModel.init)
    }
    @discardableResult func toolInsertOrUpdateChatMessage(with model: NoaIMChatMessageModel) -> Bool {
        records.removeAll { $0.localID == model.record.localID }; records.append(model.record); return true
    }
    func querySingleMsgRecord(_ params: NSMutableDictionary, onSuccess: @escaping LingIMSuccessCallback, onFailure: @escaping LingIMFailureCallback) {
        kinds.append("single"); query(params, success: onSuccess, failure: onFailure)
    }
    func queryGroupMsgRecord(_ params: NSMutableDictionary, onSuccess: @escaping LingIMSuccessCallback, onFailure: @escaping LingIMFailureCallback) {
        kinds.append("group"); query(params, success: onSuccess, failure: onFailure)
    }
    func query(_ params: NSMutableDictionary, success: @escaping LingIMSuccessCallback, failure: @escaping LingIMFailureCallback) {
        let values = params as! [String: Any]; requests.append(values)
        if fails { failure(1, "网络不可用", nil); return }
        if suspend { pending = success; return }
        if malformed { success(["unexpected": []], nil); return }
        let before = Int64(values["sMsgId"] as? String ?? "") ?? Int64.max
        let page = remote.filter { $0.timestamp < before }.sorted { $0.timestamp > $1.timestamp }.prefix(limit)
        success(["rows": page.map { ["record": $0] }], nil)
    }
}
@MainActor final class ChatRuntime {
    static let shared = ChatRuntime()
    var revision = UUID()
    func contentRevision(_ context: ChatContext) -> UUID { revision }
}
@MainActor final class HistoryClient: ChatClient {
    let sdk = HistoryDatabase()
    var groupDetail: [String: Any]?
    var eventHandler: ((ChatEvent) -> Void)?
    var active = false
    func validate(_ context: ChatContext) throws { if !active { throw ChatClientError.sessionExpired } }
    func refreshGroup(context: ChatContext) async throws { groupDetail = [:] }
    func flushReadTransitions(context: ChatContext) throws {}
    func clearManualReadTag(context: ChatContext) throws {}
    func request(context: ChatContext, start: (@escaping LingIMSuccessCallback, @escaping LingIMFailureCallback) -> Void) async throws -> [String: Any] {
        let waiter = SDKChatRequestWaiter<[String: Any]>()
        return try await waiter.run {
            start({ data, _ in waiter.finish(.success(data)) }, { _, message, _ in waiter.finish(.failure(ChatClientError.unavailable(message ?? "失败"))) })
        }
    }
    func observe(context: ChatContext, onEvent: @escaping @MainActor (ChatEvent) -> Void) { active = true; eventHandler = onEvent }
    func stop() { active = false }
    func send(_ message: ChatMessageRecord, context: ChatContext) throws {}
    func permissions(context: ChatContext) throws -> ChatPermission { ChatPermission() }
    func read(_ messages: [ChatMessageRecord], context: ChatContext) async throws {}
    func perform(_ action: ChatMessageAction, message: ChatMessageRecord, context: ChatContext) async throws {}
}

@main struct HistoryPaginationChecks {
    @MainActor static func main() async {
        var failures = 0
        var checks = 0
        func check(_ value: Bool, _ name: String) {
            checks += 1
            if !value { failures += 1; print("FAIL: " + name) }
        }
        for kind in [ConversationKind.single, .group] {
            let context = ChatContext(userUID: "me", tenantID: "club", sessionID: UUID(), route: ChatRoute(id: "peer", kind: kind, title: "", avatarURL: ""))
            let client = HistoryClient(); let store = ChatStore(client: client)
            client.sdk.records = (1...150).map(message)
            await store.open(context)
            check(store.messages.count == 100 && store.hasMore, "\(kind) 服务端空首屏不能关闭仍有本机历史的下拉入口")
            await store.loadMore()
            check(store.messages.count == 150 && store.messages.first?.serverID == "1", "\(kind) 下拉补齐本机首屏之外50条")
            check(!store.hasMore, "\(kind) 本机和服务端均结束才停止分页")
            store.close()

            client.sdk.records = []; client.sdk.remote = (1...101).map(message); client.sdk.limit = 20
            await store.open(context)
            check(store.messages.count == 20 && store.hasMore, "\(kind) 实际返回不足请求100条仍允许继续游标查询")
            for _ in 0..<7 where store.hasMore { await store.loadMore() }
            check(store.messages.count == 101 && !store.hasMore, "\(kind) 服务端短页连续下拉直到空页，不漏更早消息")
            check(client.sdk.requests.contains { $0["sMsgId"] as? String == "82" && $0["isThanMsgId"] as? Int == 1 && $0["pageNumber"] as? Int == 1 }, "\(kind) 下拉沿最早服务端ID并保持pageNumber1")
            check(client.sdk.kinds.allSatisfy { $0 == (kind == .group ? "group" : "single") }, "\(kind) 历史请求使用对应单聊或群聊接口")
            store.close()

            client.sdk.remote = []; client.sdk.records = (1...101).map(message); client.sdk.fails = true
            await store.open(context); await store.loadMore()
            check(store.messages.count == 101, "\(kind) 网络失败仍可下拉翻阅SDK本机历史")
            check(store.hasMore, "\(kind) 网络失败不把未知远端误判为结束")
            store.close()

            client.sdk.fails = false; client.sdk.limit = 100
            client.sdk.records = []; client.sdk.remote = (1...101).map(message)
            await store.open(context); await store.loadMore(); await store.loadMore()
            check(store.messages.count == 101 && !store.hasMore, "\(kind) 100/101边界没有重复或遗漏")
            store.close()

            // xgd首屏以服务器状态回写旧缓存；新端不能永久信任之前残留的删除状态。
            var staleDeleted = message(2); staleDeleted.status = .deleted
            client.sdk.records = [message(1), staleDeleted, message(3)]
            client.sdk.remote = (1...3).map(message)
            await store.open(context)
            check(store.messages.map(\.serverID) == ["1", "2", "3"], "\(kind) 进入页面自动按服务端正常状态补回中间旧缓存缺口，无需下拉")
            store.close()

            client.sdk.records = [message(1), staleDeleted, message(3)]
            client.sdk.remote = [message(1), staleDeleted, message(3)]
            await store.open(context)
            check(!store.messages.contains { $0.serverID == "2" }, "\(kind) 服务端仍为删除的消息不能恢复")
            store.close()

            client.sdk.records = (1...3).map(message); client.sdk.remote = [message(3)]
            await store.open(context)
            client.sdk.records[client.sdk.records.firstIndex { $0.serverID == "2" }!].status = .deleted
            client.eventHandler?(.upsert(staleDeleted))
            client.sdk.remote = (1...3).map(message)
            await store.loadMore()
            check(store.messages.contains { $0.serverID == "2" }, "\(kind) 服务端校正同时清理页面旧状态，不能SDK恢复后UI仍隐藏")
            store.close()

            client.sdk.records = (1...3).map(message); client.sdk.remote = [message(3)]
            await store.open(context)
            client.sdk.suspend = true
            let changing = Task { await store.refreshHistory() }
            while client.sdk.pending == nil { await Task.yield() }
            client.sdk.records[client.sdk.records.firstIndex { $0.serverID == "2" }!].status = .deleted
            client.eventHandler?(.upsert(staleDeleted))
            client.sdk.suspend = false
            client.sdk.pending?(["rows": [["record": message(2)]]], nil); client.sdk.pending = nil
            await changing.value
            check(!store.messages.contains { $0.serverID == "2" } && client.sdk.records.first { $0.serverID == "2" }?.status == .deleted,
                  "\(kind) 请求期间刚删除的消息继续保护，旧回包不能恢复")
            store.close(); client.sdk.suspend = false

            client.sdk.records = (81...180).map(message)
            client.sdk.remote = (1...180).map(message); client.sdk.limit = 20
            await store.open(context); await store.loadMore()
            check(store.messages.first?.serverID == "61", "\(kind) 本机已含最新100条时，一次下拉跨过重复远端短页取到更早正文")
            store.close(); client.sdk.limit = 100

            // 空页仅结束本次翻页；旧端下一次手动下拉仍会查询服务器。
            client.sdk.records = []; client.sdk.remote = [message(101)]
            await store.open(context); await store.loadMore()
            check(!store.hasMore, "\(kind) 空页结束当前自动翻页")
            client.sdk.remote = (1...101).map(message)
            await store.loadMore()
            check(store.messages.count == 101, "\(kind) 空页后再次手动下拉可以补到随后可用的历史")
            store.close()

            let hiddenPages = (2...301).map { value -> ChatMessageRecord in
                var record = message(value); record.type = 13; return record
            }
            client.sdk.records = []; client.sdk.remote = [message(1)] + hiddenPages
            await store.open(context); await store.loadMore()
            check(store.messages.contains { $0.serverID == "1" }, "\(kind) 一次下拉跨过连续隐藏页，直到出现正文")
            store.close()

            let controls = (2...101).map { value -> ChatMessageRecord in
                var record = message(value); record.type = 13; return record
            }
            client.sdk.records = []; client.sdk.remote = [message(1)] + controls
            await store.open(context); await store.loadMore()
            check(store.messages.first?.serverID == "1", "\(kind) 首页全是隐藏控制条，游标仍须前进到更早正文")
            store.close()

            client.sdk.remote = []; client.sdk.records = [message(1)] + controls
            await store.open(context); await store.loadMore()
            check(store.messages.first?.serverID == "1", "\(kind) 本机隐藏记录不应使可见条数offset反复停在第一页")
            store.close()
        }
        let context = ChatContext(userUID: "me", tenantID: "club", sessionID: UUID(), route: ChatRoute(id: "peer", kind: .single, title: "", avatarURL: ""))
        let client = HistoryClient(); let store = ChatStore(client: client)
        client.sdk.remote = [message(101)]
        await store.open(context)
        client.sdk.suspend = true
        let refresh = Task { await store.invokePullToRefresh() }
        while client.sdk.pending == nil { await Task.yield() }
        refresh.cancel()
        for _ in 0..<10 { await Task.yield() }
        client.sdk.pending?(["rows": [["record": message(100)]]], nil); client.sdk.pending = nil
        await refresh.value
        check(store.messages.contains { $0.serverID == "100" }, "刷新控件取消外层Task但聊天仍打开时，历史请求应完成并合并")
        client.sdk.suspend = true
        let requestsBefore = client.sdk.requests.count
        let firstRefresh = Task { await store.invokePullToRefresh() }
        while client.sdk.pending == nil { await Task.yield() }
        let secondRefresh = Task { await store.invokePullToRefresh() }
        for _ in 0..<10 { await Task.yield() }
        check(client.sdk.requests.count == requestsBefore + 1, "重复刷新共享同一在途请求")
        store.close()
        await firstRefresh.value; await secondRefresh.value
        client.sdk.pending?(["rows": [["record": message(99)]]], nil); client.sdk.pending = nil
        check(store.messages.isEmpty && !client.sdk.records.contains { $0.serverID == "99" }, "离开聊天取消持有任务，迟到回复不写库或发布")

        client.sdk.suspend = false
        await store.open(context)
        client.sdk.suspend = true
        let clearedRefresh = Task { await store.invokePullToRefresh() }
        while client.sdk.pending == nil { await Task.yield() }
        client.eventHandler?(.cleared)
        await clearedRefresh.value
        client.sdk.pending?(["rows": [["record": message(98)]]], nil); client.sdk.pending = nil
        check(store.messages.isEmpty && !client.sdk.records.contains { $0.serverID == "98" }, "清空聊天取消持有任务，迟到回复不能恢复旧消息")
        store.close(); client.sdk.suspend = false; client.sdk.remote = []; client.sdk.records = []
        client.sdk.fails = true
        await store.open(context)
        check(store.errorMessage != nil && store.hasMore, "无本机回退的网络失败保留失败提示和重试")
        client.sdk.fails = false; client.sdk.malformed = true
        await store.loadMore()
        check(store.errorMessage != nil && store.hasMore, "非法响应不当成空页关闭分页")
        client.sdk.malformed = false; client.sdk.suspend = true
        let loading = Task { await store.loadMore() }
        while client.sdk.pending == nil { await Task.yield() }
        store.close()
        client.sdk.pending?(["rows": [["record": message(1)]]], nil); client.sdk.pending = nil
        await loading.value
        check(store.messages.isEmpty && client.sdk.records.isEmpty, "退出后迟到历史不能发布或写入SDK库")
        print("历史分页检查：\(checks - failures)/\(checks)通过")
        if failures > 0 { exit(1) }
    }
    static func message(_ value: Int) -> ChatMessageRecord {
        ChatMessageRecord(localID: "local-\(value)", serverID: "\(value)", conversationID: "peer", senderID: "peer", senderName: "好友", text: "历史\(value)", timestamp: Int64(value), state: .sent)
    }
}
