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

    /// 固定身份及不可变回调，SDK事件不直接持有页面。
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

    /// 新会话到达后触发当前轮次重读。
    func cimToolSessionReceive(with model: LingIMSessionModel) { onChange(.changed) }
    /// 同步期间保存最新消息，完成后统一持久化。
    func cimToolSessionUpdate(with model: LingIMSessionModel) {
        lock.lock()
        if syncing, let message = model.sessionLatestMessage,
           !(Int(message.messageType.rawValue) == 8 && message.backDelInformSwitch == 2) {
            latestMessages.append(message)
        }
        lock.unlock()
        onChange(.changed)
    }
    /// 删除会话后刷新列表和角标。
    func cimToolSessionDelete(with model: LingIMSessionModel) { onChange(.changed) }
    /// 分页同步累积预览，不把未落库模型直接交给页面。
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
    /// 总未读通知后按当前可见会话重新计算。
    func cimToolSessionTotalUnreadCountChange(_ totalUnreadCount: Int) { onChange(.changed) }
    /// 新同步轮次使旧持久化作业失效。
    func imSdkSessionSyncStart() {
        lock.lock()
        syncVersion &+= 1
        syncing = true
        latestMessages.removeAll()
        lock.unlock()
        onChange(.syncStarted)
    }
    /// 完成同步后保存可用预览，再发布完成状态。
    func imSdkSessionSyncFinish() {
        lock.lock()
        let messages = LatestMessages(latestMessages)
        let finishedVersion = syncVersion
        latestMessages.removeAll()
        syncing = false
        lock.unlock()
        persist(messages, version: finishedVersion, then: .syncFinished)
    }
    /// 失败仍保留已收到的分页数据，便于展示缓存。
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
    /// SDK 全局已读事件需先更新数据库；单纯重读会残留旧未读数。
    func imSdkSessionListAllRead(_ lastServerMsgId: String) {
        let sdk = NoaIMSDKManager.sharedTool()
        objc_sync_enter(sdk)
        defer { objc_sync_exit(sdk) }
        lock.lock()
        let isCurrent = active
        lock.unlock()
        guard isCurrent, sdk.myUserID() == userUID, sdk.isUserDatabaseReady() else { return }
        // 在接收事件的顺序点同步更新，不排入后台队列延迟清掉后来到达的消息。
        sdk.toolSessionListAllRead()
        onChange(.changed)
    }

    /// 串行持久化需同时验证SDK身份与同步版本。
    private func persist(_ messages: LatestMessages, version: UInt64, then change: ConversationsChange) {
        // SDK 已完成会话表写入。预览持久化在后台串行进行，完成后再触发 UI 重读。
        persistenceQueue.async { [self] in
            let sdk = NoaIMSDKManager.sharedTool()
            objc_sync_enter(sdk)
            lock.lock()
            let isCurrent = active && syncVersion == version
            lock.unlock()
            if isCurrent, sdk.myUserID() == userUID, sdk.isUserDatabaseReady() {
                let values = messages.values.filter { message in
                    let type = Int(message.chatType.rawValue)
                    guard type == 0 || type == 1 else { return true }
                    let sessionID = type == 1 ? message.toID ?? "" : (message.fromID == userUID ? message.toID ?? "" : message.fromID ?? "")
                    guard !sessionID.isEmpty else { return false }
                    var cached: NoaIMChatMessageModel?
                    if let sid = message.serviceMsgID, !sid.isEmpty {
                        cached = sdk.toolGetOneChatMessage(withServiceMessageID: sid, sessionID: sessionID)
                    }
                    if cached == nil, let mid = message.msgID, !mid.isEmpty {
                        cached = sdk.toolGetOneChatMessage(withMessageID: mid, sessionID: sessionID)
                    }
                    // AUTH会话latest可能仍为正常原文；批量SDK写入会直接replace，必须先保护真实库的删除/撤回墓碑。
                    // 老项目也继承了这一无条件写库路径；这里以本机已受理状态为准，不用内存删除ID补丁。
                    return cached?.messageStatus != 0 && cached?.messageStatus != 2
                }
                if !values.isEmpty { sdk.toolInsertOrUpdateChatMessages(with: values) }
                onChange(change)
            }
            objc_sync_exit(sdk)
        }
    }
}

nonisolated private final class LatestMessages: @unchecked Sendable {
    let values: [NoaIMChatMessageModel]
    /// Sendable封装只在受保护的持久化队列消费SDK模型。
    init(_ values: [NoaIMChatMessageModel]) { self.values = values }
}
