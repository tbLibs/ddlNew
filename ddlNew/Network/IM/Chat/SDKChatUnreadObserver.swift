//
//  SDKChatUnreadObserver.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//
import Foundation
import NoaChatCore
import ObjectiveC

/// AUTH期间观察真实计数来源，独立于聊天页面生命周期；不修改SDK消息与会话表。
@MainActor final class SDKChatUnreadObserver {
    private var delegate: SDKChatUnreadDelegate?
    private var generation = UUID()

    func activate(owner: ChatReadCountOwner, onEvent: @escaping @MainActor (ChatReadCountEvent) -> Void) {
        close(); let run = generation
        let delegate = SDKChatUnreadDelegate(owner: owner) { [weak self] event in
            Task { @MainActor [weak self] in
                let sdk = NoaIMSDKManager.sharedTool()
                guard self?.generation == run, sdk.myUserID() == owner.userUID,
                      sdk.mySsoInfo() == owner.tenantID, sdk.isUserDatabaseReady() else { return }
                onEvent(event)
            }
        }
        self.delegate = delegate
        let sdk = NoaIMSDKManager.sharedTool(); sdk.addSessionDelegate(delegate); sdk.addMessageDelegate(delegate)
    }

    func close() {
        generation = UUID()
        if let delegate {
            let sdk = NoaIMSDKManager.sharedTool(); sdk.removeSessionDelegate(delegate); sdk.removeMessageDelegate(delegate)
        }
        delegate = nil
    }
}

/// SDK可变对象只在回调线程取值，零计数事件和真实receive分别变成不可变来源快照。
nonisolated private final class SDKChatUnreadDelegate: NSObject, NoaToolSessionDelegate, NoaToolMessageDelegate, @unchecked Sendable {
    private let owner: ChatReadCountOwner
    private let changed: @Sendable (ChatReadCountEvent) -> Void
    init(owner: ChatReadCountOwner, changed: @escaping @Sendable (ChatReadCountEvent) -> Void) { self.owner = owner; self.changed = changed }

    func cimToolSessionReceive(with model: LingIMSessionModel) { publish(model) }
    func cimToolSessionUpdate(with model: LingIMSessionModel) { publish(model) }
    func cimToolSessionDelete(with model: LingIMSessionModel) { publish(model, cleared: true) }

    /// 权威分页先于SDK批量写库，旧计数成员资格在收到真实回执时失效；不在此修改红点。
    func cimToolSessionListUpdate(with modelList: [LingIMSessionModel], topSessionList: [LingIMSessionModel], isFirstPage: Bool) {
        let sdk = NoaIMSDKManager.sharedTool()
        guard sdk.myUserID() == owner.userUID, sdk.mySsoInfo() == owner.tenantID, sdk.isUserDatabaseReady() else { return }
        for model in modelList + topSessionList { if let value = snapshot(model) { changed(.authoritative(value)) } }
    }

    /// SDK普通receive在isRemind写入会话后派发；历史/编辑/update回调不注册计数成员。
    func cimToolChatMessageReceive(_ message: NoaIMChatMessageModel) {
        let sdk = NoaIMSDKManager.sharedTool()
        objc_sync_enter(sdk); defer { objc_sync_exit(sdk) }
        guard sdk.myUserID() == owner.userUID, sdk.mySsoInfo() == owner.tenantID, sdk.isUserDatabaseReady(),
              [0, 1].contains(Int(message.chatType.rawValue)) else { return }
        let record = SDKChatMessageMapper.record(message, userUID: owner.userUID)
        guard !ChatVisibleReadPolicy.candidates([record], userUID: owner.userUID, conversationID: record.conversationID).isEmpty,
              let model = (sdk.toolCheckMySession(with: record.conversationID) as LingIMSessionModel?), let snapshot = snapshot(model) else { return }
        changed(.received(record, snapshot))
    }

    private func publish(_ model: LingIMSessionModel, cleared: Bool = false) {
        let sdk = NoaIMSDKManager.sharedTool()
        guard sdk.myUserID() == owner.userUID, sdk.mySsoInfo() == owner.tenantID, sdk.isUserDatabaseReady(),
              var value = snapshot(model) else { return }
        if cleared { value.count = 0 }
        changed(.counter(value))
    }

    private func snapshot(_ model: LingIMSessionModel) -> ChatReadCountSnapshot? {
        guard let id = model.sessionID, !id.isEmpty else { return nil }
        let kind: ConversationKind
        switch Int(model.sessionType.rawValue) { case 1: kind = .single; case 2: kind = .group; default: return nil }
        let latest = model.sessionLatestServerMsgID?.isEmpty == false ? model.sessionLatestServerMsgID ?? "" : model.sessionLatestMessage?.serviceMsgID ?? ""
        return ChatReadCountSnapshot(id: id, kind: kind, count: max(0, model.sessionUnreadCount), latestID: latest)
    }
}
