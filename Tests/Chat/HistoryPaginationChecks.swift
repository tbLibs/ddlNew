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
    var messageStatus: Int
    var chatMessageReaded: Bool { get { record.isRead } set { record.isRead = newValue } }
    var haveReadCount: Int { get { record.readCount } set { record.readCount = newValue } }
    var totalNeedReadCount: Int { get { record.totalReadCount } set { record.totalReadCount = newValue } }
    var msgID: String { get { record.localID } set { record.localID = newValue } }
    var sendTime: Int64 { get { record.timestamp } set { record.timestamp = newValue } }
    var messageSendType = HistorySendType()
    init(_ record: ChatMessageRecord) { self.record = record; messageStatus = record.status.rawValue }
}
enum SDKChatMessageMapper {
    static func record(_ model: NoaIMChatMessageModel, userUID: String) -> ChatMessageRecord {
        var value = model.record; value.status = ProductionMessageStatus.map(model.messageStatus); return value
    }
    static func historyModel(_ row: [String: Any], context: ChatContext) -> NoaIMChatMessageModel {
        let model = NoaIMChatMessageModel(row["record"] as! ChatMessageRecord)
        model.messageStatus = row["sdkStatus"] as? Int ?? model.messageStatus
        return model
    }
}
typealias LingIMSuccessCallback = ([String: Any], String?) -> Void
typealias LingIMFailureCallback = (Int, String?, String?) -> Void
@MainActor final class HistoryDatabase: NSObject {
    var records: [ChatMessageRecord] = []
    var remote: [ChatMessageRecord] = []
    var storedStatuses: [String: Int] = [:]
    var remoteStatuses: [String: Int] = [:]
    func storedModel(_ record: ChatMessageRecord) -> NoaIMChatMessageModel {
        let model = NoaIMChatMessageModel(record)
        model.messageStatus = storedStatuses[record.localID] ?? record.status.rawValue
        return model
    }
    var limit = 100
    var fails = false
    var rejectedWriteIDs: Set<String> = []
    var malformed = false
    var suspend = false
    var pending: LingIMSuccessCallback?
    var requests: [[String: Any]] = []
    var kinds: [String] = []
    func toolGetChatMessageHistory(with id: String, offset: Int) -> Any {
        records.filter { $0.conversationID == id && (storedStatuses[$0.localID] ?? $0.status.rawValue) == 1 }
            .sorted { $0.timestamp > $1.timestamp }.dropFirst(offset).prefix(100).reversed().map(storedModel)
    }
    func toolGetChatMessageTimeline(with id: String, offset: Int) -> Any {
        records.filter { $0.conversationID == id && ProductionTimelineStatus.includes(storedStatuses[$0.localID] ?? $0.status.rawValue) }
            .sorted { $0.timestamp > $1.timestamp }.dropFirst(offset).prefix(100).reversed().map(storedModel)
    }
    func toolGetChatMessageHistoryIncludingInactive(with id: String, offset: Int) -> Any {
        records.filter { $0.conversationID == id }.sorted { $0.timestamp > $1.timestamp }
            .dropFirst(offset).prefix(100).map(storedModel)
    }
    func toolGetOneChatMessage(withServiceMessageID id: String, sessionID: String) -> NoaIMChatMessageModel? {
        records.first { $0.serverID == id && $0.conversationID == sessionID }.map(storedModel)
    }
    func toolGetOneChatMessage(withMessageID id: String, sessionID: String) -> NoaIMChatMessageModel? {
        records.first { $0.localID == id && $0.conversationID == sessionID }.map(storedModel)
    }
    @discardableResult func toolInsertOrUpdateChatMessage(with model: NoaIMChatMessageModel) -> Bool {
        if rejectedWriteIDs.contains(model.record.serverID) { return false }
        storedStatuses[model.msgID] = [0, 1, 2].contains(model.messageStatus) ? nil : model.messageStatus
        let value = SDKChatMessageMapper.record(model, userUID: "me")
        records.removeAll { $0.localID == value.localID }; records.append(value); return true
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
        success(["rows": page.map { ["record": $0, "sdkStatus": remoteStatuses[$0.localID] ?? $0.status.rawValue] }], nil)
    }
}
@MainActor final class ChatRuntime {
    static let shared = ChatRuntime()
    var revision = UUID()
    func contentRevision(_ context: ChatContext) -> UUID { revision }
}
@MainActor final class HistoryClient: ChatClient {
    let sdk = HistoryDatabase()
    var context: ChatContext?
    var generation = UUID()
    var groupPermissionTask: Task<Void, Never>?
    var groupPermissionRequest: UUID?
    var groupDetail: [String: Any]?
    var eventHandler: ((ChatEvent) -> Void)?
    var active = false
    var failGroupRefresh = false
    func validate(_ context: ChatContext) throws { if !active { throw ChatClientError.sessionExpired } }
    func refreshGroup(context: ChatContext) async throws { if failGroupRefresh { throw ChatClientError.unavailable("群资料失败") }; groupDetail = [:] }
    func flushReadTransitions(context: ChatContext) throws {}
    func clearManualReadTag(context: ChatContext) throws {}
    func request(context: ChatContext, start: (@escaping LingIMSuccessCallback, @escaping LingIMFailureCallback) -> Void) async throws -> [String: Any] {
        let waiter = SDKChatRequestWaiter<[String: Any]>()
        return try await waiter.run {
            start({ data, _ in waiter.finish(.success(data)) }, { _, message, _ in waiter.finish(.failure(ChatClientError.unavailable(message ?? "失败"))) })
        }
    }
    func observe(context: ChatContext, onEvent: @escaping @MainActor (ChatEvent) -> Void) { active = true; self.context = context; eventHandler = onEvent }
    func stop() { active = false; context = nil; generation = UUID(); groupPermissionTask?.cancel(); groupPermissionTask = nil; groupPermissionRequest = nil; groupDetail = nil }
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
        let groupContext = ChatContext(userUID: "me", tenantID: "club", sessionID: UUID(), route: ChatRoute(id: "peer", kind: .group, title: "", avatarURL: ""))
        let independent = HistoryClient(); independent.active = true; independent.failGroupRefresh = true
        independent.sdk.remote = [message(1)]
        let independentPage = try? await independent.history(context: groupContext, before: nil, offset: 0)
        check(independent.sdk.requests.count == 1 && independentPage?.messages.count == 1,
              "群资料接口失败也不能阻止群历史请求与显示")
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

            client.sdk.records = (501...600).map(message); client.sdk.remote = (1...100).map(message)
            await store.open(context)
            check(store.messages.count == 200 && store.messages.first?.serverID == "1",
                  "\(kind) 本地最新页之外的有效服务端历史也参与合并，不能直接丢弃")
            check(client.sdk.records.contains { $0.serverID == "1" }, "\(kind) 页外远端历史仍落库供后续翻阅")
            store.close()

            // 两张本人图片在有效服务端历史页中，但被本地100条窗口挤出时仍须显示。
            var firstImage = ChatMessageRecord(localID: "own-image-1", serverID: "1", conversationID: "peer", senderID: "me", senderName: "本人", type: 1, text: "", timestamp: 1, state: .sent)
            firstImage.resource = "/fixture/first.jpg"; firstImage.thumbnail = "/fixture/first-thumb.jpg"
            var secondImage = ChatMessageRecord(localID: "own-image-2", serverID: "2", conversationID: "peer", senderID: "me", senderName: "本人", type: 1, text: "", timestamp: 2, state: .sent)
            secondImage.resource = "/fixture/second.jpg"; secondImage.thumbnail = "/fixture/second-thumb.jpg"
            client.sdk.records = (3...102).map(message)
            client.sdk.remote = [firstImage, secondImage] + (3...100).map(message)
            await store.open(context)
            let images = store.messages.filter { $0.type == 1 && $0.senderID == "me" }
            check(images.map(\.serverID) == ["1", "2"], "\(kind) 本地首屏未包含的两张本人图片不能从聊天中消失")
            check(images.map(\.resource) == [firstImage.resource, secondImage.resource], "\(kind) 图片合并保留真实资源路径")
            check(store.messages.count == 102, "\(kind) 图片与已缓存正文按双ID去重，不重复插入")
            store.close()

            // 真机分布：60条中46条正常、13条原始状态3（11图2视频）、1条删除。
            let rawPage = (1...60).map { index -> ChatMessageRecord in
                var value = message(index)
                if index <= 11 { value.type = 1; value.resource = "/fixture/image-\(index).jpg" }
                else if index <= 13 { value.type = 2 }
                if index == 60 { value.status = .deleted }
                return value
            }
            client.sdk.records = rawPage; client.sdk.remote = rawPage
            let nonNormalStatuses = Dictionary(uniqueKeysWithValues: rawPage.prefix(13).map { ($0.localID, 3) })
            client.sdk.storedStatuses = nonNormalStatuses; client.sdk.remoteStatuses = nonNormalStatuses
            for entry in 1...2 {
                client.sdk.suspend = true
                let opening = Task { await store.open(context) }
                while client.sdk.pending == nil { await Task.yield() }
                check(store.messages.count == 46, "\(kind) 第\(entry)次进入的本地首屏只含46条正常消息")
                client.sdk.pending?(["rows": rawPage.map { ["record": $0, "sdkStatus": nonNormalStatuses[$0.localID] ?? $0.status.rawValue] }], nil)
                client.sdk.pending = nil; await opening.value
                check(store.messages.count == 46 && store.messages.allSatisfy(\.isVisible),
                      "\(kind) 第\(entry)次远端返回后不能把状态3的13条误加到首屏导致跳动")
                check(client.sdk.toolGetOneChatMessage(withMessageID: rawPage[0].localID, sessionID: "peer")?.messageStatus == 3,
                      "\(kind) 展示修复不能把真实SDK状态3改写为正常或删除")
                check(store.referenceSummary(rawPage[0].serverID) != rawPage[0].senderName + ": " + rawPage[0].displayText,
                      "\(kind) 非正常状态的引用不能继续显示原媒体正文")
                store.close(); client.sdk.suspend = false
            }
            // 后续进入时服务器确实恢复为正常，仍可显示，不能永久屏蔽这些ID。
            client.sdk.remoteStatuses = [:]
            await store.open(context)
            check(store.messages.count == 59 && store.messages.filter { $0.type == 1 }.count == 11,
                  "\(kind) 服务器实际恢复状态1后正常图片可回读并展示")
            store.close(); client.sdk.storedStatuses = [:]

            // 撤回原条已落库，但没有对应type8控制条时，首屏也必须直接显示占位。
            var recalled = message(2); recalled.status = .recalled
            for entry in 1...2 {
                client.sdk.records = [message(1), recalled, message(3)]
                client.sdk.remote = client.sdk.records; client.sdk.suspend = true
                let opening = Task { await store.open(context) }
                while client.sdk.pending == nil { await Task.yield() }
                let initialIDs = store.messages.map(\.serverID)
                check(initialIDs == ["1", "2", "3"] && store.messages.first { $0.serverID == "2" }?.displayText == "消息已撤回",
                      "\(kind) 第\(entry)次进群/单聊在网络返回前就显示本地撤回占位")
                client.sdk.pending?(["rows": client.sdk.remote.map { ["record": $0] }], nil)
                client.sdk.pending = nil; await opening.value
                check(store.messages.map(\.serverID) == initialIDs,
                      "\(kind) 撤回历史网络补拉前后列表身份保持一致，不再晚插占位")
                store.close(); client.sdk.suspend = false
            }
            client.sdk.records = [message(1), recalled, message(3)]; client.sdk.fails = true
            await store.open(context)
            check(store.messages.map(\.serverID) == ["1", "2", "3"], "\(kind) 离线进聊天仍能看到已缓存的撤回占位")
            store.close(); client.sdk.fails = false

            // 撤回状态参与相同的100条窗口，分页不能因补插占位而错位或跳过正文。
            client.sdk.records = (1...205).map { index in
                var value = message(index)
                if index % 2 == 0 { value.status = .recalled }
                return value
            }
            client.sdk.remote = []
            await store.open(context)
            check(store.messages.count == 100 && store.messages.first?.serverID == "106", "\(kind) 首屏按正常和撤回合计100条分页")
            await store.loadMore(); await store.loadMore()
            check(store.messages.count == 205 && Set(store.messages.map(\.serverID)).count == 205,
                  "\(kind) 正常和撤回交错的跨页记录无遗漏无重复")
            check(store.messages.filter { $0.status == .recalled }.count == 102, "\(kind) 更早页面的撤回占位也不会被过滤")
            store.close()

            // SDK落库失败也不能让已经收到的正常图片悄悄从本次展示中丢失。
            firstImage.localID = "own-image-101"; firstImage.serverID = "101"; firstImage.timestamp = 101
            secondImage.localID = "own-image-102"; secondImage.serverID = "102"; secondImage.timestamp = 102
            client.sdk.records = (1...20).map(message)
            client.sdk.remote = [firstImage, secondImage]
            client.sdk.rejectedWriteIDs = ["101", "102"]
            await store.open(context)
            check(store.messages.filter { $0.type == 1 }.count == 2,
                  "\(kind) SDK回读缺少已收到的两张图片时仍保留服务端有效结果")
            store.close(); client.sdk.rejectedWriteIDs = []

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
