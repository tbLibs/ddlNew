//
//  SDKConversationsDelegate.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation
import NoaChatCore
import ObjectiveC

/// 会话变化转成刷新信号；分页回调先于 SDK 会话表写入，完成后再持久化预览并重读。
nonisolated final class SDKConversationsDelegate: NSObject, NoaToolSessionDelegate, @unchecked Sendable {
    private let userUID: String
    private let onChange: @Sendable (ConversationsChange) -> Void
    private let lock = NSLock()
    /// 同步期间收到的最新消息不随会话模型入库，暂存到同步结束后批量写入消息表。
    private var latestMessages: [NoaIMChatMessageModel] = []
    private var syncing = false
    /// 后台持久化可能晚于下一轮同步；版本号用于丢弃过期写入与回调。
    private var syncVersion: UInt64 = 0
    private var active = true
    private let persistenceQueue = DispatchQueue(label: "ddlNew.conversationPreviewPersistence", qos: .utility)

    init(userUID: String, onChange: @escaping @Sendable (ConversationsChange) -> Void) {
        self.userUID = userUID
        self.onChange = onChange
    }

    /// 与预览写库使用同一把 SDK 锁，确保退出后不会写入下一轮数据库。
    func invalidate() {
        let sdk = NoaIMSDKManager.sharedTool()
        objc_sync_enter(sdk)
        lock.lock()
        active = false
        syncVersion &+= 1
        syncing = false
        latestMessages.removeAll()
        lock.unlock()
        objc_sync_exit(sdk)
    }

    func cimToolSessionReceive(with model: LingIMSessionModel) { onChange(.changed) }
    func cimToolSessionUpdate(with model: LingIMSessionModel) {
        lock.lock()
        if syncing, let message = model.sessionLatestMessage,
           !(Int(message.messageType.rawValue) == 8 && message.backDelInformSwitch == 2) {
            latestMessages.append(message)
        }
        lock.unlock()
        onChange(.changed)
    }
    func cimToolSessionDelete(with model: LingIMSessionModel) { onChange(.changed) }
    func cimToolSessionListUpdate(with modelList: [LingIMSessionModel], topSessionList: [LingIMSessionModel], isFirstPage: Bool) {
        lock.lock()
        if isFirstPage { latestMessages.removeAll() }
        for model in modelList {
            guard let message = model.sessionLatestMessage else { continue }
            // 与老项目一致：部分撤回通知不作为历史消息写入。
            if Int(message.messageType.rawValue) == 8 && message.backDelInformSwitch == 2 { continue }
            latestMessages.append(message)
        }
        lock.unlock()
    }
    func cimToolSessionTotalUnreadCountChange(_ totalUnreadCount: Int) { onChange(.changed) }
    func imSdkSessionSyncStart() {
        lock.lock()
        syncVersion &+= 1
        syncing = true
        latestMessages.removeAll()
        lock.unlock()
        onChange(.syncStarted)
    }
    func imSdkSessionSyncFinish() {
        lock.lock()
        let messages = LatestMessages(latestMessages)
        let finishedVersion = syncVersion
        latestMessages.removeAll()
        syncing = false
        lock.unlock()
        persist(messages, version: finishedVersion, then: .syncFinished)
    }
    func imSdkSessionSyncFailed(_ errorMsg: String?) {
        lock.lock()
        syncVersion &+= 1
        let failedVersion = syncVersion
        let messages = LatestMessages(latestMessages)
        latestMessages.removeAll()
        syncing = false
        lock.unlock()
        // 前几页可能已落库；失败时也保存已收到的预览，再显示可用缓存。
        persist(messages, version: failedVersion, then: .syncFailed(errorMsg ?? "会话同步失败"))
    }
    func imSdkSessionListAllRead(_ lastServerMsgId: String) { onChange(.changed) }

    private func persist(_ messages: LatestMessages, version: UInt64, then change: ConversationsChange) {
        // SDK 已完成会话表写入。预览持久化在后台串行进行，完成后再触发 UI 重读。
        persistenceQueue.async { [self] in
            let sdk = NoaIMSDKManager.sharedTool()
            objc_sync_enter(sdk)
            lock.lock()
            let isCurrent = active && syncVersion == version
            lock.unlock()
            if isCurrent, sdk.myUserID() == userUID, sdk.isUserDatabaseReady() {
                if !messages.values.isEmpty { sdk.toolInsertOrUpdateChatMessages(with: messages.values) }
                onChange(change)
            }
            objc_sync_exit(sdk)
        }
    }
}

nonisolated private final class LatestMessages: @unchecked Sendable {
    let values: [NoaIMChatMessageModel]
    init(_ values: [NoaIMChatMessageModel]) { self.values = values }
}
