//
//  ConversationsStore.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Combine
import Foundation

/// SDK 会话数据库的展示快照。冷启动先读本地缓存，AUTH 与同步更新同一列表。
@MainActor
final class ConversationsStore: ObservableObject {
    @Published private(set) var conversations: [ConversationRecord] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var totalUnreadCount = 0
    @Published private(set) var hasLoadedSnapshot = false
    @Published private(set) var busyConversationIDs: Set<String> = []
    @Published private(set) var operationError: String?

    private let client: any ConversationsClient
    /// UID 与轮次共同隔离退出、切换账号后的迟到代理事件和异步读取结果。
    private var userUID: String?
    private var generation = UUID()
    private var syncError: String?
    private var cacheError: String?
    /// 合并同一轮内的多次 SDK 事件；读取期间又有变化时再补读一次。
    private var reloadTask: Task<Void, Never>?
    private var reloadRequested = false
    private var allConversations: [ConversationRecord] = []
    private var fileAssistantVisible = false
    private var sessionPrepared = false

    /// 注入数据与操作客户端，便于隔离 SDK 和离线回归。
    init(client: any ConversationsClient) { self.client = client }

    /// AUTH 前绑定当前账号，丢弃旧轮次回调。
    func prepare(for userUID: String, preservingSnapshot: Bool = false) {
        if preservingSnapshot, self.userUID == userUID { suspend() } else { reset() }
        sessionPrepared = true
        self.userUID = userUID
        isSyncing = true
        let runID = generation
        client.observe(for: userUID) { [weak self] change in
            guard let self, self.generation == runID, self.userUID == userUID else { return }
            switch change {
            case .syncStarted:
                self.isSyncing = true
                self.syncError = nil
                self.updateError()
            case .changed:
                self.requestReload()
            case .syncFinished:
                self.isSyncing = false
                self.requestReload()
            case .syncFailed(let message):
                self.isSyncing = false
                self.syncError = message.isEmpty ? L10n.tr("会话同步失败，请检查网络连接") : message
                self.updateError()
                self.requestReload()
            }
        }
    }

    /// 不依赖网络或 AUTH；异步结果仍受账号及轮次隔离。
    func loadLocalSnapshot(for userUID: String,
                           load: @MainActor () async throws -> [ConversationRecord]) async {
        if self.userUID == userUID { suspend() } else { reset() }
        self.userUID = userUID
        let runID = generation
        do {
            let records = try await load()
            let snapshot = await Task.detached { ConversationSorter.sorted(records) }.value
            guard !Task.isCancelled, generation == runID else { return }
            allConversations = snapshot
            publishVisibleConversations()
            hasLoadedSnapshot = true
            cacheError = nil
            updateError()
        } catch {
            guard !Task.isCancelled, generation == runID else { return }
            cacheError = L10n.tr("会话缓存读取失败：\(error.localizedDescription)")
            updateError()
        }
    }

    /// 暂时恢复失败只停止旧轮次的读写与订阅，屏幕上的同账号快照继续保留。
    func suspend() {
        generation = UUID()
        reloadTask?.cancel()
        reloadTask = nil
        reloadRequested = false
        client.stopObserving()
        sessionPrepared = false
        isSyncing = false
        busyConversationIDs = []
        operationError = nil
        syncError = nil
        updateError()
    }

    /// 合并同时到达的缓存读取请求，保留同步失败时的已有数据。
    func reload() async {
        guard sessionPrepared, let userUID else { return }
        if let reloadTask { await reloadTask.value; return }
        let runID = generation
        let task = Task { [weak self] in
            await Task.yield()
            guard let self, self.generation == runID else { return }
            repeat {
                self.reloadRequested = false
                do {
                    let records = try await self.client.loadConversations(for: userUID)
                    let snapshot = await Task.detached { ConversationSorter.sorted(records) }.value
                    guard !Task.isCancelled, self.generation == runID else { return }
                    self.allConversations = snapshot
                    self.publishVisibleConversations()
                    self.hasLoadedSnapshot = true
                    self.cacheError = nil
                } catch {
                    guard !Task.isCancelled, self.generation == runID else { return }
                    self.cacheError = L10n.tr("会话缓存读取失败：\(error.localizedDescription)")
                }
                self.updateError()
            } while self.reloadRequested && !Task.isCancelled
            self.reloadTask = nil
        }
        reloadTask = task
        await task.value
    }

    /// 读取期间发生变化时补读一次。
    private func requestReload() {
        if reloadTask != nil {
            reloadRequested = true
            return
        }
        let runID = generation
        Task { [weak self] in
            guard let self, self.generation == runID else { return }
            await self.reload()
        }
    }

    /// 旧端文件助手是单聊系统账号 100002；权限更新只重算展示，保留 SDK 缓存。
    func setFileAssistantVisible(_ visible: Bool) {
        fileAssistantVisible = visible
        publishVisibleConversations()
    }

    /// 支付通知不展示；文件助手继续按角色权限生成列表与角标。
    private func publishVisibleConversations() {
        conversations = allConversations.filter {
            $0.kind != .paymentAssistant && (fileAssistantVisible || $0.kind != .single || $0.id != "100002")
        }
        // 角标与实际可见列表保持一致，权限关闭不能残留隐藏会话未读数。
        totalUnreadCount = ConversationUnread.total(conversations)
    }

    /// 同步错误优先展示，缓存失败允许页面单独重试。
    var hasLocalCacheFailure: Bool { cacheError != nil }

    private func updateError() { errorMessage = syncError ?? cacheError }

    /// 操作按会话去重；退出或换账号后不能写入旧请求的结果与错误。
    func perform(_ action: ConversationAction, conversationID: String) async {
        guard sessionPrepared, let userUID, !busyConversationIDs.contains(conversationID),
              let conversation = conversations.first(where: { $0.id == conversationID }),
              ConversationActionPolicy.allowed(for: conversation).contains(action),
              let operations = client as? any ConversationOperationsClient else { return }
        let runID = generation
        busyConversationIDs.insert(conversationID)
        operationError = nil
        defer {
            if generation == runID { busyConversationIDs.remove(conversationID) }
        }
        do {
            try await operations.perform(action, conversation: conversation, userUID: userUID)
            guard generation == runID, self.userUID == userUID, !Task.isCancelled else { return }
            await reload()
        } catch {
            guard generation == runID, self.userUID == userUID, !(error is CancellationError) else { return }
            operationError = error.localizedDescription
        }
    }

    /// 关闭操作提示不会改变 SDK 数据。
    func clearOperationError() { operationError = nil }

    /// 登出释放订阅和正在运行的读取，移除所有用户快照。
    func reset() {
        suspend()
        hasLoadedSnapshot = false
        userUID = nil
        allConversations = []
        fileAssistantVisible = false
        conversations = []
        totalUnreadCount = 0
        isSyncing = false
        errorMessage = nil
        syncError = nil
        cacheError = nil
        busyConversationIDs = []
        operationError = nil
    }
}
