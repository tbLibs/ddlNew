//
//  ConversationsStore.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Combine
import Foundation

/// SDK 会话数据库的展示快照。AUTH 前订阅事件，AUTH 后加载缓存。
@MainActor
final class ConversationsStore: ObservableObject {
    @Published private(set) var conversations: [ConversationRecord] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var totalUnreadCount = 0

    private let client: any ConversationsClient
    /// UID 与轮次共同隔离退出、切换账号后的迟到代理事件和异步读取结果。
    private var userUID: String?
    private var generation = UUID()
    private var syncError: String?
    private var cacheError: String?
    /// 合并同一轮内的多次 SDK 事件；读取期间又有变化时再补读一次。
    private var reloadTask: Task<Void, Never>?
    private var reloadRequested = false

    init(client: any ConversationsClient) { self.client = client }

    func prepare(for userUID: String) {
        reset()
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
                self.syncError = message.isEmpty ? "会话同步失败，请检查网络连接" : message
                self.updateError()
                self.requestReload()
            }
        }
    }

    func reload() async {
        guard let userUID else { return }
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
                    self.conversations = snapshot
                    // 仅统计已展示的已知类型会话；SDK 原始总未读还可能包含隐藏或未知类型。
                    self.totalUnreadCount = ConversationUnread.total(snapshot)
                    self.cacheError = nil
                } catch {
                    guard !Task.isCancelled, self.generation == runID else { return }
                    self.cacheError = "会话缓存读取失败：\(error.localizedDescription)"
                }
                self.updateError()
            } while self.reloadRequested && !Task.isCancelled
            self.reloadTask = nil
        }
        reloadTask = task
        await task.value
    }

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

    private func updateError() { errorMessage = syncError ?? cacheError }

    func reset() {
        generation = UUID()
        reloadTask?.cancel()
        reloadTask = nil
        reloadRequested = false
        client.stopObserving()
        userUID = nil
        conversations = []
        totalUnreadCount = 0
        isSyncing = false
        errorMessage = nil
        syncError = nil
        cacheError = nil
    }
}
