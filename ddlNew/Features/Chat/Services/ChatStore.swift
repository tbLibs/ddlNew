//
//  ChatStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import Combine

/// 聊天状态只拥有当前会话快照，SDK承担落库、网络重试和最终ACK。
@MainActor final class ChatStore: ObservableObject {
    @Published var input = ""
    @Published private(set) var messages: [ChatMessageRecord] = []
    @Published private(set) var permission = ChatPermission(canSend: false)
    @Published private(set) var isLoading = false
    @Published private(set) var hasMore = true
    @Published var errorMessage: String?
    @Published var reference: ChatMessageRecord?
    @Published private(set) var mentions: [ChatMentionSegment] = []
    private var previousInput = ""
    @Published private(set) var selectedIDs: Set<String> = []
    @Published private(set) var busyIDs: Set<String> = []
    @Published private(set) var unreadArrivals = 0
    /// 仅SDK确认发送成功后递增，页面据此执行一次最新消息定位。
    @Published private(set) var sendSuccessRevision = 0
    /// 刷新型置顶事件不插入正文，但仍通知页面重读置顶列表。
    @Published private(set) var pinRevision = 0
    @Published private(set) var locatedMessageID: String?
    /// 定位是一次动作，同一条消息重复点击也必须通知页面。
    @Published private(set) var locationRevision = 0
    private var locationRequest = UUID()
    var isAtBottom = true
    /// 前台恢复不保证几何变化，需要重新评估原视口里的未读正文。
    var isForeground = true { didSet { if isForeground && !oldValue { resumeVisibleReads() } } }
    /// 设置页或附件返回聊天时，原可见消息仍须重新进入批处理。
    var isVisible = true { didSet { if isVisible && !oldValue { resumeVisibleReads() } } }
    /// 运行时接收原消息失效，状态层不直接依赖播放器或下载实现。
    var onMessageUnavailable: (@MainActor (ChatMessageRecord?, ChatContext) -> Void)?
    private var visibleIDs: Set<String> = []
    private var queuedReads: [String: ChatMessageRecord] = [:]
    private var readFlushTask: Task<Void, Never>?
    private(set) var context: ChatContext?
    weak var mediaRetryClient: (any ChatMediaRetryClient)?
    private let client: any ChatClient
    private var generation = UUID()
    private var records: [ChatMessageRecord] = []
    private var eventRevision = 0
    private var clearRevision = UUID()
    private var changedIDs: [String: Int] = [:]
    private var offset = 0
    private var historyCursor: String?
    private var refreshTask: Task<Void, Never>?
    private var refreshRequestID = UUID()
    private var lastSend: Date?
    private var readIDs: Set<String> = []
    /// 在途已读按批次持有资格，旧回执的清理不能撤销新批次。
    private var pendingReadOwners: [String: UUID] = [:]

    /// 测试注入可暂停客户端，生产注入真实SDK。
    init(client: any ChatClient) { self.client = client }

    /// 订阅先于缓存与补页，避免首屏读取期间漏掉实时消息。
    func open(_ context: ChatContext) async {
        if self.context == context { isForeground = true; return }
        close()
        self.context = context
        let run = generation
        client.observe(context: context) { [weak self] event in
            guard let self, self.generation == run, self.context == context else { return }
            self.receive(event)
        }
        // 沿旧端进入即清会话提醒；独立于正文可见/语音播放及历史加载，快速返回也已落库。
        do {
            try client.clearConversationUnread(context: context) { [weak self] message in
                guard let self, self.generation == run, self.context == context else { return }
                self.errorMessage = message
            }
        } catch { errorMessage = error.localizedDescription }
        do {
            merge(try client.cached(context: context, offset: 0), history: true)
            permission = try client.permissions(context: context)
            let draft = try client.draft(context: context)
            input = draft.text; previousInput = input; mentions = draft.mentions
            if !draft.referenceID.isEmpty { reference = messages.first { $0.serverID == draft.referenceID } ?? ChatMessageRecord(localID: "reference:" + draft.referenceID, serverID: draft.referenceID, conversationID: context.route.id, senderID: "", senderName: "", text: "引用原文尚未加载，点击定位", timestamp: 0, state: .sent) }
        } catch { errorMessage = error.localizedDescription }
        await loadPage(before: nil)
        if let target = context.route.targetMessageID { await locate(target) }
    }

    /// 下拉控件的任务可能随SwiftUI刷新取消，网络补页由当前聊天持有。
    /// 真正离开或清空聊天时仍同步取消，不能把旧请求带进下一会话。
    func refreshHistory() async {
        if let refreshTask { await refreshTask.value; return }
        guard context != nil, !isLoading else { return }
        let id = UUID(); refreshRequestID = id
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.loadMore()
        }
        refreshTask = task
        await task.value
        if refreshRequestID == id { refreshTask = nil }
    }

    /// 手动下拉允许重试空页；连续隐藏/重复页在一次手势内继续补查正文。
    func loadMore() async {
        guard let context, !isLoading else { return }
        let run = generation
        let visibleBefore = Set(messages.filter(\.isVisible).map(\.id))
        // 单次手势限制补查次数，防止异常服务端或大量控制条占用页面；下次可接着拉。
        for _ in 0..<5 {
            let previousCursor = historyCursor
            let previousOffset = offset
            await loadPage(before: historyCursor ?? messages.first(where: { !$0.serverID.isEmpty })?.serverID)
            guard !Task.isCancelled, generation == run, self.context == context else { return }
            if messages.contains(where: { $0.isVisible && !visibleBefore.contains($0.id) }) { return }
            guard hasMore, historyCursor != previousCursor || offset != previousOffset else { return }
        }
    }

    /// 合并远程补页而非覆盖实时消息；轮次改变后不发布任何结果。
    private func loadPage(before: String?) async {
        guard let context, !isLoading else { return }
        let run = generation
        let beganAt = eventRevision
        let clearAtStart = clearRevision
        isLoading = true
        #if DEBUG
        print("[ChatHistory] start older=\(before != nil) offset=\(offset) knownMore=\(hasMore)")
        #endif
        defer { if generation == run { isLoading = false } }
        do {
            let page = try await client.history(context: context, before: before, offset: offset)
            guard !Task.isCancelled, generation == run, self.context == context, clearRevision == clearAtStart else { return }
            for message in page.messages {
                let changedAfterRequest = (changedIDs[message.localID] ?? 0) > beganAt || (changedIDs[message.serverID] ?? 0) > beganAt
                if !changedAfterRequest, message.status == .normal, page.restoredServerIDs.contains(message.serverID) {
                    records.removeAll { $0.status != .normal && $0.serverID == message.serverID }
                }
                merge([message], history: changedAfterRequest)
            }
            offset = page.nextOffset ?? messages.count
            historyCursor = page.nextCursor ?? before
            hasMore = page.hasMore
            #if DEBUG
            print("[ChatHistory] finish received=\(page.messages.count) visible=\(messages.filter(\.isVisible).count) offset=\(offset) more=\(hasMore)")
            #endif
        } catch {
            #if DEBUG
            print("[ChatHistory] failed taskCancelled=\(Task.isCancelled) cancellationError=\(error is CancellationError) contextChanged=\(generation != run)")
            #endif
            guard generation == run, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// 提交前复核权限；原文入SDK队列后清输入，失败记录保留可重发内容。
    func sendText() {
        guard let context, !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        errorMessage = nil
        do {
            try checkSend(context)
            reconcileMentions()
            var record = ChatMessageRecord(localID: UUID().uuidString, conversationID: context.route.id,
                senderID: context.userUID, senderName: "我", text: input,
                timestamp: Int64(Date().timeIntervalSince1970 * 1000), referenceID: reference?.serverID ?? "")
            if !mentions.isEmpty { record.type = 10; record.mentions = mentions }
            record = try client.prepareMessage(record, context: context)
            try client.send(record, context: context)
            merge([record])
            input = ""; previousInput = ""; mentions = []; reference = nil; lastSend = Date(); persistDraft()
        } catch { errorMessage = error.localizedDescription }
    }

    /// 复核实时群权限和普通成员频控，管理者不受发送间隔限制。
    private func checkSend(_ context: ChatContext, messageType: Int? = nil) throws {
        permission = try client.permissions(context: context)
        guard permission.isActive, permission.canSend else { throw ChatClientError.permission(permission.reason.isEmpty ? "当前会话暂不能发送消息" : permission.reason) }
        if let messageType, [1, 2, 5].contains(messageType), !(messageType == 5 ? permission.canUploadFile : permission.canUpload) { throw ChatClientError.permission("当前账号不允许上传此附件") }
        if context.route.kind == .group, permission.role == 0, let lastSend,
           Date().timeIntervalSince(lastSend) < permission.sendInterval { throw ChatClientError.permission("发送过于频繁，请稍后重试") }
    }

    /// 图片/视频先以本地资源占位；上传完成后用同一 localID 接续 SDK 消息。
    func beginMediaUpload(_ message: ChatMessageRecord) throws {
        guard let context, message.conversationID == context.route.id,
              message.senderID == context.userUID, message.isMediaUploading,
              [1, 2].contains(message.type) else { throw ChatClientError.sessionExpired }
        try checkSend(context, messageType: message.type)
        guard !records.contains(where: { $0.localID == message.localID && $0.status != .normal }) else { throw ChatClientError.sessionExpired }
        merge([message], retrying: true)
    }

    /// 失败原件随SDK本地消息保存；页面不移除气泡，退出重进仍可重传。
    func failMediaUpload(_ message: ChatMessageRecord) {
        guard let context, message.conversationID == context.route.id, message.senderID == context.userUID,
              let current = records.first(where: { $0.localID == message.localID }),
              current.status == .normal, current.state != .sent else { return }
        var failed = message; failed.state = .failed; failed.isMediaUploading = false
        merge([failed])
        do { try client.saveFailedMedia(failed, context: context) }
        catch { errorMessage = error.localizedDescription }
    }

    func discardMediaUpload(_ localID: String) {
        guard records.contains(where: { $0.localID == localID && $0.isMediaUploading }) else { return }
        records.removeAll { $0.localID == localID && $0.isMediaUploading }
        messages = records.filter { $0.status != .deleted }
    }

    /// 已上传附件再入SDK消息队列，提交时重新校验实时禁言和频控。
    func sendAttachment(_ message: ChatMessageRecord) throws {
        guard let context, message.conversationID == context.route.id, message.senderID == context.userUID else { throw ChatClientError.sessionExpired }
        errorMessage = nil
        try checkSend(context, messageType: message.type)
        try client.send(message, context: context)
        merge([message]); lastSend = Date()
    }

    /// 游戏结果沿旧端在客户端生成，作为独立type21发送，保留正在编辑的文字和引用。
    func sendGame(_ game: ChatGameSticker) {
        guard let context else { return }
        var message = ChatMessageRecord(localID: UUID().uuidString, conversationID: context.route.id,
            senderID: context.userUID, senderName: "我", type: 21, text: game.randomResult(),
            timestamp: Int64(Date().timeIntervalSince1970 * 1000))
        message.gameType = game.rawValue
        do { try sendAttachment(message) } catch { errorMessage = error.localizedDescription }
    }

    /// 动画只影响展示；已变更/删除的消息和旧会话不能被完成回调恢复。
    func completeGameAnimation(_ message: ChatMessageRecord) {
        guard let context, let current = messages.first(where: { $0.id == message.id }),
              current.type == 21, current.status == .normal, current.text == message.text,
              current.gameType == message.gameType, current.timestamp == message.timestamp,
              !current.gameAnimationPlayed else { return }
        try? client.markGameAnimationPlayed(current, context: context)
        var played = current; played.gameAnimationPlayed = true; merge([played])
    }

    /// 人工重发复用原本地ID；成功消息和发送中消息不重复入队。
    func retry(_ id: String) {
        guard let context, !busyIDs.contains(id), let index = messages.firstIndex(where: { $0.id == id }),
              messages[index].status == .normal, messages[index].state == .failed else { return }
        errorMessage = nil
        do {
            try checkSend(context, messageType: messages[index].type)
            var message = messages[index]
            if [1, 2].contains(message.type), message.resource.isEmpty || message.thumbnail.isEmpty {
                guard let mediaRetryClient else { throw ChatClientError.unavailable("附件上传器尚未就绪，请稍后重试") }
                let run = generation; let clearRun = clearRevision
                busyIDs.insert(id)
                Task { [weak self] in
                    guard let self else { return }
                    defer { if self.generation == run { self.busyIDs.remove(id) } }
                    guard self.generation == run, self.clearRevision == clearRun, self.context == context else { return }
                    await mediaRetryClient.retry(message, context: context,
                        stage: { [weak self] value in
                            guard let self, self.generation == run, self.clearRevision == clearRun, self.context == context else { throw ChatClientError.sessionExpired }
                            try self.beginMediaUpload(value)
                        }, discard: { [weak self] value in
                            guard let self, self.generation == run, self.clearRevision == clearRun, self.context == context else { return }
                            self.discardMediaUpload(value)
                        }, failed: { [weak self] value in
                            guard let self, self.generation == run, self.clearRevision == clearRun, self.context == context else { return }
                            self.failMediaUpload(value)
                        }, enqueue: { [weak self] value in
                            guard let self, self.generation == run, self.clearRevision == clearRun, self.context == context,
                                  !self.isMessageDeleted(value) else { throw ChatClientError.sessionExpired }
                            try self.sendAttachment(value)
                        })
                }
                return
            }
            if message.type == 21, let game = ChatGameSticker(rawValue: message.gameType) {
                message.text = game.randomResult(); message.gameAnimationPlayed = false
            }
            message.state = .sending; message.failure = nil
            message.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
            let localFile = message.localMediaFileURL
            message.localMediaFileURL = nil; message.localMediaPreviewURL = nil
            do { try client.send(message, context: context) }
            catch {
                if [1, 2].contains(message.type) { return }
                throw error
            }
            merge([message], retrying: true); lastSend = Date()
            ChatUploadFiles.remove(localFile)
        } catch { errorMessage = error.localizedDescription }
    }

    /// 可见收到正文才已读；语音必须实际播放，清历史后的旧回执不能恢复附件。
    func markVisible(_ id: String, voicePlayed: Bool = false) async {
        guard isForeground, (isVisible || voicePlayed), let context,
              let item = messages.first(where: { $0.id == id }), item.senderID != context.userUID,
              item.isBody, !item.isRead, !item.serverID.isEmpty,
              (item.type != 4 || voicePlayed), !readIDs.contains(item.serverID), pendingReadOwners[item.serverID] == nil else { return }
        if voicePlayed {
            let run = generation; let clearRun = clearRevision; let batch = UUID()
            pendingReadOwners[item.serverID] = batch
            defer { if generation == run, pendingReadOwners[item.serverID] == batch { pendingReadOwners.removeValue(forKey: item.serverID) } }
            do {
                try await client.read([item], context: context)
                guard generation == run, clearRevision == clearRun else { return }
                readIDs.insert(item.serverID)
                if var changed = messages.first(where: { $0.id == id }) { changed.isRead = true; merge([changed]) }
            } catch { if generation == run, clearRevision == clearRun { errorMessage = error.localizedDescription } }
        } else {
            queuedReads[item.serverID] = item
            if readFlushTask == nil {
                let run = generation
                readFlushTask = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
                    guard let self, self.generation == run else { return }
                    self.readFlushTask = nil; await self.flushVisibleReads()
                }
            }
        }
    }

    /// 视口变化同步当前可见ID，离开视口的正文在批处理时不会误上报。
    func setVisibleMessageIDs(_ ids: Set<String>) { visibleIDs = ids }

    /// 恢复只重报当前视口，异步任务核对认证轮次，语音仍由实际播放触发。
    private func resumeVisibleReads() {
        guard isForeground, isVisible, context != nil else { return }
        let run = generation; let clearRun = clearRevision
        let ids = visibleIDs
        Task { [weak self] in
            guard let self, self.generation == run, self.clearRevision == clearRun else { return }
            for id in ids {
                guard self.generation == run, self.clearRevision == clearRun else { return }
                await self.markVisible(id)
            }
        }
    }

    /// 可见正文合为SDK批次；清历史撤销旧完成结果，避免再次合并已清正文。
    func flushVisibleReads() async {
        guard isForeground, isVisible, let context else { queuedReads.removeAll(); return }
        let run = generation; let clearRun = clearRevision
        let values = queuedReads.values.filter { visibleIDs.contains($0.id) && !readIDs.contains($0.serverID) && pendingReadOwners[$0.serverID] == nil }
        queuedReads.removeAll()
        guard !values.isEmpty else { return }
        let batch = UUID()
        for value in values { pendingReadOwners[value.serverID] = batch }
        defer {
            if generation == run {
                for value in values where pendingReadOwners[value.serverID] == batch { pendingReadOwners.removeValue(forKey: value.serverID) }
            }
        }
        do {
            try await client.read(Array(values), context: context)
            guard generation == run, clearRevision == clearRun else { return }
            readIDs.formUnion(values.map(\.serverID))
            // 一个已读批次只排序并发布一次，避免滚动中逐条刷新整个聊天列表。
            let updated = values.map { value in var value = value; value.isRead = true; return value }
            merge(updated)
        } catch { if generation == run, clearRevision == clearRun { errorMessage = error.localizedDescription } }
    }

    /// 引用摘要即时读取原记录，原文编辑、撤回和删除不显示旧副本。
    func referenceSummary(_ serverID: String) -> String {
        guard !serverID.isEmpty else { return "" }
        guard let original = records.first(where: { $0.serverID == serverID }) else { return "引用原文尚未加载，点击定位" }
        if original.status == .deleted { return "原消息已删除" }
        return original.senderName + ": " + original.displayText
    }

    /// 附件详情重试前读取真实墓碑，不能因气泡隐藏后又下载被删原条。
    func isMessageDeleted(_ message: ChatMessageRecord) -> Bool { records.contains { $0.status != .normal && (!$0.localID.isEmpty && $0.localID == message.localID || !$0.serverID.isEmpty && $0.serverID == message.serverID) } }

    /// 管理删除成员消息后保留墓碑，迟到历史不能复活被删正文。
    func removeSenderMessages(_ ids: Set<String>) {
        clearRevision = UUID()
        eventRevision += 1
        let removed = records.filter { ids.contains($0.senderID) }.map { record -> ChatMessageRecord in var value = record; value.status = .deleted; return value }
        merge(removed)
        selectedIDs = selectedIDs.intersection(messages.map(\.id))
        queuedReads = queuedReads.filter { !ids.contains($0.value.senderID) }
    }

    /// 选择只保留允许类型，最多100条稳定ID。
    func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) { selectedIDs.remove(id); return }
        guard let context, let item = messages.first(where: { $0.id == id }),
              ChatActionPolicy.allowed(for: item, userUID: context.userUID, permission: permission).contains(.select) else { return }
        guard selectedIDs.count < 100 else { errorMessage = "一次最多选择100条消息"; return }
        selectedIDs.insert(id)
    }

    /// 取消多选保留编辑中的正文与引用。
    func cancelSelection() { selectedIDs.removeAll() }

    /// 长按操作提交前重新校验权限，服务端成功后才改本地消息范围。
    @discardableResult func perform(_ action: ChatMessageAction, id: String) async -> Bool {
        guard let context, !busyIDs.contains(id), let item = messages.first(where: { $0.id == id }) else { return false }
        let run = generation
        defer { if generation == run { busyIDs.remove(id) } }
        do {
            permission = try client.permissions(context: context)
            guard ChatActionPolicy.allowed(for: item, userUID: context.userUID, permission: permission).contains(action) else { throw ChatClientError.permission("当前消息已不允许此操作") }
            busyIDs.insert(id)
            try await client.perform(action, message: item, context: context)
            guard generation == run, !Task.isCancelled else { return false }
            if action == .delete || action == .deleteBoth { ChatUploadFiles.remove(item.localMediaFileURL); var deleted = item; deleted.status = .deleted; merge([deleted]); selectedIDs.remove(id) }
            if action == .recall { var recalled = item; recalled.status = .recalled; merge([recalled]) }
            return true
        } catch { if generation == run { errorMessage = error.localizedDescription }; return false }
    }

    /// 多选逐条真实提交并保留失败选择，未确认项不能当作批量成功。
    func deleteSelected(both: Bool) async {
        guard let context else { return }
        let ids = messages.filter { selectedIDs.contains($0.id) }.map(\.id)
        var failures: [String] = []; var successCount = 0
        for (index, id) in ids.enumerated() {
            guard self.context == context, !Task.isCancelled else { return }
            if await perform(both ? .deleteBoth : .delete, id: id) { successCount += 1 }
            else { failures.append("第\(index + 1)条：" + (errorMessage ?? "未获得删除确认")) }
        }
        guard self.context == context else { return }
        errorMessage = failures.isEmpty ? nil : "已确认删除\(successCount)条，\(failures.count)条未删除\n" + failures.joined(separator: "\n")
    }

    /// ACK必须含服务端ID；网络迟到失败不能覆盖成功，明确的业务拒收仍须显示失败。
    private func receive(_ event: ChatEvent) {
        switch event {
        case .upsert(let item):
            eventRevision += 1; changedIDs[item.localID] = eventRevision; changedIDs[item.serverID] = eventRevision
            guard item.conversationID == context?.route.id else { return }
            let isNew = !messages.contains { $0.localID == item.localID || (!item.serverID.isEmpty && $0.serverID == item.serverID) }
            merge([item])
            if isNew && !isAtBottom { unreadArrivals += 1 }
            selectedIDs = selectedIDs.intersection(messages.filter { $0.state == .sent && $0.isBody }.map(\.id))
        case .ack(let localID, let serverID, let timestamp):
            guard !serverID.isEmpty, var item = messages.first(where: { $0.localID == localID }),
                  item.conversationID == context?.route.id, item.senderID == context?.userUID,
                  item.failure?.isBlacklistRejection != true else { return }
            item.serverID = serverID; item.state = .sent; item.failure = nil
            if timestamp > 0 { item.timestamp = timestamp }
            eventRevision += 1; changedIDs[localID] = eventRevision; changedIDs[serverID] = eventRevision
            merge([item], ack: true)
            sendSuccessRevision += 1
        case .failed(let localID, let reason):
            guard let index = messages.firstIndex(where: { $0.localID == localID }), messages[index].state != .sent else { return }
            var failed = messages[index]; failed.state = .failed; failed.failure = reason; merge([failed])
            // 图片/视频仅显示失败标记与重试，其他类型保留原有反馈。
            if ![1, 2].contains(failed.type) { errorMessage = reason.message }
        case .blacklistRejected(let localID, let reason):
            guard context?.route.kind == .single, reason.isBlacklistRejection,
                  var item = messages.first(where: { !$0.localID.isEmpty && $0.localID == localID }),
                  item.conversationID == context?.route.id, item.senderID == context?.userUID, item.isBody else { return }
            item.state = .failed; item.failure = reason
            eventRevision += 1; changedIDs[localID] = eventRevision; changedIDs[item.serverID] = eventRevision
            merge([item])
            selectedIDs.remove(item.id)
        case .cleared:
            refreshTask?.cancel(); refreshTask = nil; refreshRequestID = UUID()
            if let context { onMessageUnavailable?(nil, context) }
            // 清历史同时撤销待发送已读；已在途批次由clearRevision拒绝迟到回写。
            readFlushTask?.cancel(); readFlushTask = nil
            queuedReads.removeAll(); visibleIDs.removeAll(); pendingReadOwners.removeAll(); readIDs.removeAll()
            for item in records { ChatUploadFiles.remove(item.localMediaFileURL) }
            clearRevision = UUID(); hasMore = false; records.removeAll(); messages.removeAll(); selectedIDs.removeAll(); offset = 0; historyCursor = nil
        case .memberHistoryDeleted(let ids): removeSenderMessages(Set(ids))
        case .memberMetadataChanged(let members):
            remapSenders(members)
        case .memberMetadataRefresh: break
        case .permissionsChanged:
            if let context { do { permission = try client.permissions(context: context) } catch { permission.canSend = false } }
        case .pinsChanged: pinRevision += 1
        case .refresh:
            if let context { do { merge(try client.cached(context: context, offset: 0), history: true) } catch { errorMessage = error.localizedDescription } }
        }
    }

    /// 外部群资料刷新按当前完整上下文更新作者元数据，禁止串群串账号。
    func applyMemberMetadata(_ members: [ChatGroupMember], context: ChatContext) { if self.context == context { remapSenders(members) } }

    /// 成员昵称与角色刷新仅替换作者展示，不回退正文、ACK、引用和删除墓碑。
    private func remapSenders(_ members: [ChatGroupMember]) {
        let mapping = Dictionary(members.map { ($0.id, $0) }, uniquingKeysWith: { _, newest in newest })
        records = records.map { item in
            guard let member = mapping[item.senderID] else { return item }
            var result = item; result.senderName = member.name
            if member.isDeleted { result.avatarURL = "" }
            else if !member.avatar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.avatarURL = member.avatar }
            result.senderRole = member.role
            return result
        }
        messages = records.filter { $0.status != .deleted }
        if let reference, let current = records.first(where: { $0.serverID == reference.serverID }) { self.reference = current }
    }

    /// 编辑或转发回执只合并属于当前会话且登录上下文仍相同的消息。
    func applyOperationMessages(_ incoming: [ChatMessageRecord], context: ChatContext) {
        guard self.context == context else { return }
        for item in incoming where item.conversationID == context.route.id {
            eventRevision += 1; changedIDs[item.localID] = eventRevision; changedIDs[item.serverID] = eventRevision
            merge([item])
        }
    }

    /// 逐条转发接口返回真实服务端ID后回到当前会话最新消息；合并转发仍等待SDK ACK。
    func applyForwardedMessages(_ incoming: [ChatMessageRecord], context: ChatContext) {
        guard self.context == context else { return }
        applyOperationMessages(incoming, context: context)
        if incoming.contains(where: { $0.conversationID == context.route.id && $0.senderID == context.userUID && $0.state == .sent && !$0.serverID.isEmpty }) {
            sendSuccessRevision += 1
        }
    }

    /// 用户编辑和离页时保存SDK草稿，保留失败发送之外的新输入。
    func persistDraft() {
        guard let context else { return }
        do { try client.saveDraft(ChatDraft(text: input, referenceID: reference?.serverID ?? "", mentions: mentions), context: context) }
        catch { errorMessage = error.localizedDescription }
    }

    /// 从成员选择追加完整片段，重名依然持有对应UID。
    func insertMention(_ member: ChatGroupMember) {
        guard permission.canSend, !(permission.role == 0 && permission.isPrivateChat), !member.isDeleted else { return }
        let display = "@" + member.name + " "
        let start = (input as NSString).length
        mentions.append(ChatMentionSegment(id: UUID(), userUID: member.id, name: member.name, location: start, length: (display as NSString).length))
        input += display; previousInput = input; persistDraft()
    }

    /// 输入@后只替换本次光标处标记，保留其后的正文和其它成员UID。
    func insertMention(_ member: ChatGroupMember, replacingAt range: NSRange) -> NSRange? {
        guard context?.route.kind == .group, permission.canSend,
              !(permission.role == 0 && permission.isPrivateChat), !member.isDeleted else { return nil }
        reconcileMentions()
        guard let result = ChatMentionEngine.inserting(userUID: member.id, name: member.name,
            replacingAt: range, in: input, segments: mentions) else { return nil }
        input = result.0; mentions = result.1; previousInput = input; persistDraft()
        return result.2
    }

    /// 文本编辑更新片段范围，局部删@时自动去掉完整片段。
    func reconcileMentions() {
        guard previousInput != input else { return }
        let result = ChatMentionEngine.editing(old: previousInput, new: input, segments: mentions)
        mentions = result.1; previousInput = result.0
        if input != result.0 { input = result.0 }
    }

    /// 隐藏删除消息但保留墓碑，迟到历史不能把原文重新插入。
    private func merge(_ incoming: [ChatMessageRecord], history: Bool = false, ack: Bool = false, retrying: Bool = false) {
        records = ChatMessageMerge.merge(records, with: incoming, history: history, ack: ack, retrying: retrying)
        messages = records.filter { $0.status != .deleted }
        if let context { for item in records where item.status != .normal { onMessageUnavailable?(item, context) } }
        if let reference, let refreshed = records.first(where: { $0.serverID == reference.serverID }) { self.reference = refreshed }
    }

    /// 按双ID定位搜索命中；每次补页仍验证当前登录轮次和游标进展。
    func locate(_ target: String) async {
        guard let context, !target.isEmpty, !Task.isCancelled else { return }
        let run = generation
        let clearRun = clearRevision
        let request = UUID(); locationRequest = request
        isAtBottom = false; errorMessage = nil
        // 旧端先按服务端ID查本机SDK库；较早置顶不应受远程分页结束或断网影响。
        if !messages.contains(where: { $0.isVisible && $0.status == .normal && ($0.localID == target || $0.serverID == target) }) {
            var cachedOffset = 0
            var history: [ChatMessageRecord] = []
            while let page = try? client.cached(context: context, offset: cachedOffset), !page.isEmpty {
                history.append(contentsOf: page)
                if page.contains(where: { $0.isVisible && $0.status == .normal && ($0.localID == target || $0.serverID == target) }) {
                    merge(history, history: true)
                    break
                }
                guard page.count == 100 else { break }
                cachedOffset += page.count
            }
        }
        while generation == run && clearRevision == clearRun && locationRequest == request && !Task.isCancelled {
            if let item = messages.first(where: { $0.isVisible && $0.status == .normal && ($0.localID == target || $0.serverID == target) }) {
                errorMessage = nil; locatedMessageID = item.id; locationRevision += 1; return
            }
            // 用户可能在首屏或下拉补页尚未结束时点击置顶，先等已有请求再重查目标。
            if isLoading {
                for await loading in $isLoading.values {
                    guard generation == run, clearRevision == clearRun,
                          locationRequest == request, !Task.isCancelled else { return }
                    if !loading { break }
                }
                continue
            }
            guard hasMore else { break }
            let previous = messages.first?.id
            let previousCursor = historyCursor; let previousOffset = offset
            await loadMore()
            guard messages.first?.id != previous || historyCursor != previousCursor || offset != previousOffset || messages.contains(where: { $0.isVisible && $0.status == .normal && ($0.localID == target || $0.serverID == target) }) else { break }
        }
        if generation == run, clearRevision == clearRun, locationRequest == request, !Task.isCancelled { errorMessage = "当前历史中未找到这条消息，可能已删除或不可访问" }
    }

    /// 用户点新消息提示时只更新浏览状态，由页面滚动到实际最新ID。
    func returnToLatest() { isAtBottom = true; unreadArrivals = 0 }

    /// 退出同时释放代理和身份，所有旧轮次异步结果失效。
    func close() {
        refreshTask?.cancel(); refreshTask = nil; refreshRequestID = UUID()
        persistDraft()
        readFlushTask?.cancel(); readFlushTask = nil; queuedReads.removeAll(); visibleIDs.removeAll()
        generation = UUID(); client.stop(); context = nil
        records.removeAll(); changedIDs.removeAll(); eventRevision = 0; messages.removeAll(); selectedIDs.removeAll(); busyIDs.removeAll()
        readIDs.removeAll(); pendingReadOwners.removeAll(); input = ""; previousInput = ""; mentions = []; reference = nil
        isLoading = false; hasMore = true; offset = 0; historyCursor = nil; lastSend = nil; unreadArrivals = 0; pinRevision = 0
        permission = ChatPermission(canSend: false); locatedMessageID = nil; locationRevision = 0; locationRequest = UUID(); errorMessage = nil
    }
}
