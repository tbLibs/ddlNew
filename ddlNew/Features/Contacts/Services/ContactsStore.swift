//
//  ContactsStore.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Combine
import Foundation

/// 只管理真实好友展示状态；SDK 负责网络同步和数据库持久化。
@MainActor
final class ContactsStore: ObservableObject {
    @Published private(set) var contacts: [ContactRecord] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var errorMessage: String?
    private let client: any ContactsClient
    /// 当前登录用户与轮次共同防止退出、切换账号后的迟到回调串数据。
    private var userUID: String?
    private var generation = UUID()
    private var syncError: String?
    private var cacheError: String?
    /// 同一批代理事件共用一次读取，读取期间的新变化再补读一遍。
    private var reloadTask: Task<Void, Never>?
    private var readingCache = false
    private var reloadRequested = false

    init(client: any ContactsClient) { self.client = client }

    /// AUTH 前监听首轮同步，数据库配置完毕后再读取缓存。
    func prepare(for userUID: String) {
        reset()
        self.userUID = userUID
        isSyncing = true
        let runID = generation
        client.observe { [weak self] change in
            guard let self, self.generation == runID, self.userUID == userUID else { return }
            switch change {
            case .syncStarted:
                self.isSyncing = true
                self.syncError = nil
                self.updateErrorMessage()
            case .changed, .remarkChanged:
                self.requestReload()
            case .syncFinished:
                self.isSyncing = false
                // 完成事件只刷新缓存，实际同步错误由下一轮开始事件清理。
                self.requestReload()
            case .syncFailed(let message):
                self.isSyncing = false
                self.syncError = message.isEmpty ? "好友同步失败，请检查网络连接" : message
                self.updateErrorMessage()
                // 分页或在线状态失败时，前面的好友可能已落库，仍需显示这部分真实数据。
                self.requestReload()
            }
        }
    }

    /// 登录 AUTH 完成或页面重新显示时读取本地缓存，不重复发起服务器同步。
    func reload() async {
        guard let userUID else { return }
        if let reloadTask {
            await reloadTask.value
            return
        }
        let runID = generation
        let task = Task { [weak self] in
            // 同一次 SDK 更新常同时触发好友变化、分组变化，先合并这一批事件。
            await Task.yield()
            guard let self, self.generation == runID else { return }
            repeat {
                self.reloadRequested = false
                self.readingCache = true
                do {
                    let records = try await self.client.loadContacts(for: userUID)
                    let snapshot = await Task.detached { ContactSorter.sorted(records) }.value
                    guard !Task.isCancelled, self.generation == runID else { return }
                    self.contacts = snapshot
                    self.cacheError = nil
                } catch {
                    guard !Task.isCancelled, self.generation == runID else { return }
                    self.cacheError = "好友缓存读取失败：\(error.localizedDescription)"
                }
                self.readingCache = false
                self.updateErrorMessage()
            } while self.reloadRequested && !Task.isCancelled
            self.reloadTask = nil
        }
        reloadTask = task
        await task.value
    }

    private func requestReload() {
        if reloadTask != nil {
            if readingCache { reloadRequested = true }
            return
        }
        let runID = generation
        Task { [weak self] in
            guard let self, self.generation == runID else { return }
            await self.reload()
        }
    }

    private func updateErrorMessage() { errorMessage = syncError ?? cacheError }

    func reset() {
        generation = UUID()
        reloadTask?.cancel()
        reloadTask = nil
        readingCache = false
        reloadRequested = false
        client.stopObserving()
        userUID = nil
        contacts = []
        isSyncing = false
        errorMessage = nil
        syncError = nil
        cacheError = nil
    }
}
