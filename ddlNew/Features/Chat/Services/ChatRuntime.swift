//
//  ChatRuntime.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import Combine

/// AUTH成功后建立聊天资格，退出同步关闭所有活跃聊天和SDK等待。
@MainActor final class ChatRuntime: ObservableObject {
    static let shared = ChatRuntime()
    @Published private(set) var userUID: String?
    @Published private(set) var revision = UUID()
    @Published private(set) var closedConversationContext: ChatContext?
    @Published private(set) var conversationCleanupWarning: String?
    private var tenantID: String?
    private var sessionID: UUID?
    private var stores: [WeakChatStore] = []
    private var contentRevisions: [String: UUID] = [:]
    private var settings: [WeakChatSettingsStore] = []
    private let nicknameObserver = SDKChatNicknameObserver()
    private let unreadObserver = SDKChatUnreadObserver()
    private var readCounts = ChatReadCountLedger()
    private var cleanupOwners: [WeakChatCleanup] = []

    /// 认证轮次由根会话所有者提供，同UID重登也产生新身份。
    func activate(userUID: String, tenantID: String, sessionID: UUID) {
        close(); self.userUID = userUID; self.tenantID = tenantID; self.sessionID = sessionID; revision = UUID()
        nicknameObserver.activate(userUID: userUID, tenantID: tenantID, sessionID: sessionID)
        readCounts.activate(userUID: userUID, tenantID: tenantID, sessionID: sessionID)
        let owner = ChatReadCountOwner(userUID: userUID, tenantID: tenantID, sessionID: sessionID)
        unreadObserver.activate(owner: owner) { [weak self] event in self?.receiveReadCount(event, owner: owner) }
    }

    /// 页面使用稳定路由生成上下文，未认证不创建可发送身份。
    func context(for route: ChatRoute) -> ChatContext? {
        guard let userUID, let tenantID, let sessionID else { return nil }
        return ChatContext(userUID: userUID, tenantID: tenantID, sessionID: sessionID, route: route)
    }

    /// SDK客户端必须在每次请求与回调时核对本轮所有权。
    func isCurrent(_ context: ChatContext) -> Bool {
        context.userUID == userUID && context.tenantID == tenantID && context.sessionID == sessionID
    }

    /// 全AUTH计数来源保持到退出；关闭一个页面不销毁正文成功但会话未保存的债务。
    private func receiveReadCount(_ event: ChatReadCountEvent, owner: ChatReadCountOwner) {
        let snapshot: ChatReadCountSnapshot
        switch event { case .counter(let value), .authoritative(let value), .received(_, let value): snapshot = value }
        let route = ChatRoute(id: snapshot.id, kind: snapshot.kind, title: "", avatarURL: "")
        guard let context = context(for: route), owner.matches(context) else { return }
        switch event {
        case .authoritative: readCounts.authoritative(context: context, count: snapshot.count, latestID: snapshot.latestID)
        case .counter: readCounts.observe(context: context, count: snapshot.count, latestID: snapshot.latestID)
        case .received(let message, _):
            guard !ChatVisibleReadPolicy.candidates([message], userUID: context.userUID, conversationID: context.route.id).isEmpty else { return }
            readCounts.received(message.serverID, context: context, count: snapshot.count, latestID: snapshot.latestID)
        }
    }

    /// 正文真实写入成功后登记；未知历史不进入会话扣减集合。
    func savedVisibleRead(_ serverID: String, context: ChatContext) {
        guard isCurrent(context) else { return }
        readCounts.saved(serverID, context: context)
    }

    /// 新聊天可能还没有SDK会话行；仅已有待扣计划时要求回读该行。
    func hasPendingVisibleReadCount(context: ChatContext) -> Bool { isCurrent(context) && readCounts.hasPending(context: context) }

    /// 客户端读SDK最新计数后取得有身份及epoch保护的待扣计划。
    func visibleReadCountPlan(context: ChatContext, count: Int, latestID: String) -> ChatReadCountPlan? {
        guard isCurrent(context) else { return nil }
        return readCounts.plan(context: context, count: count, latestID: latestID)
    }

    /// 只有SDK会话计数保存成功后才确认计划，失败保留到同AUTH下次开页。
    func commitVisibleReadCount(_ plan: ChatReadCountPlan, context: ChatContext) {
        guard isCurrent(context) else { return }
        readCounts.commit(plan, context: context)
    }

    /// 列表全清冻结请求起点，迟到回执不能替新AUTH建立已读边界。
    func beginReadCountClear(context: ChatContext, count: Int, boundaryID: String) -> ChatReadCountClearCheckpoint? {
        guard isCurrent(context) else { return nil }
        readCounts.observe(context: context, count: count, latestID: boundaryID)
        return readCounts.beginClear(context: context, boundaryID: boundaryID)
    }

    /// 真实全清成功并写库后采用请求起点，不把等待期间的新消息一起清掉。
    func confirmReadCountClear(_ checkpoint: ChatReadCountClearCheckpoint, context: ChatContext, count: Int?, latestID: String) {
        guard isCurrent(context) else { return }
        readCounts.confirmClear(checkpoint, context: context, count: count, latestID: latestID)
    }

    /// 每页独立Store与代理，以弱引用统一结束业务等待。
    func makeStore() -> ChatStore {
        let store = ChatStore(client: SDKChatClient(validSession: { [weak self] in self?.isCurrent($0) == true }))
        store.onMessageUnavailable = { [weak self] message, context in self?.invalidatePreviewMessage(message, context: context) }
        stores.removeAll { $0.value == nil }; stores.append(WeakChatStore(store))
        return store
    }

    /// 媒体、录音和独立详情共同注册同步清理，不让退出后继续传输或播放。
    func registerCleanup(owner: AnyObject, conversationID: String? = nil, action: @escaping @MainActor () -> Void) {
        cleanupOwners.removeAll { $0.owner == nil || $0.owner === owner }
        cleanupOwners.append(WeakChatCleanup(owner: owner, conversationID: conversationID, action: action))
    }

    /// 页面创建媒体Store时纳入AUTH退出取消。
    func makeMediaStore() -> ChatMediaStore {
        let store = ChatMediaStore(client: SDKChatMediaClient())
        registerCleanup(owner: store) { [weak store] in store?.cancel() }
        return store
    }

    /// 附件详情下载和音频播放由根会话统一取消。
    func makePreviewStore() -> ChatMediaPreviewStore {
        let store = ChatMediaPreviewStore()
        registerCleanup(owner: store) { [weak store] in store?.close() }
        return store
    }

    /// 录音页退出账号后立即释放麦克风及临时文件。
    func makeRecorder() -> ChatVoiceRecorder {
        let store = ChatVoiceRecorder()
        registerCleanup(owner: store) { [weak store] in store?.cancel() }
        return store
    }

    /// 来电/呼出接管音频前关闭播放器与未发送录音，不取消附件上传。
    func prepareForCall() {
        for reference in cleanupOwners {
            if reference.owner is ChatVoiceRecorder || reference.owner is ChatMediaPreviewStore { reference.action() }
        }
    }

    /// 消息清空版本用来阻止在清空前发起的旧补页回写SDK数据库。
    func contentRevision(_ context: ChatContext) -> UUID? { contentRevisions[context.route.id] }

    /// 清空版本只属于本轮身份，同UID重新登录不会继承旧等待。
    func markCleared(_ context: ChatContext) {
        guard isCurrent(context) else { return }
        contentRevisions[context.route.id] = UUID()
        invalidatePreviewMessage(nil, context: context)
    }

    /// 状态层只提供失效事件，由运行时统一关闭对应已打开附件。
    private func invalidatePreviewMessage(_ message: ChatMessageRecord?, context: ChatContext) {
        guard isCurrent(context) else { return }
        for reference in cleanupOwners { (reference.owner as? ChatMediaPreviewStore)?.invalidateMessage(message, context: context) }
    }

    /// 删除好友或退出群后同步关闭指定聊天并清其媒体，其他会话保持可用。
    func closeConversation(context: ChatContext) {
        guard isCurrent(context) else { return }
        closedConversationContext = context
        conversationCleanupWarning = nil
        closeConversation(id: context.route.id)
    }

    /// 离群已经受理，后续清理失败只提示重读会话，不误报退出失败。
    func reportConversationCleanupFailure(context: ChatContext) {
        guard isCurrent(context), closedConversationContext == context else { return }
        conversationCleanupWarning = "群操作已受理，会话清理失败，请刷新消息列表"
    }

    /// 删除好友保留原ID入口；群退出使用携带认证轮次的事件入口。
    func closeConversation(id: String) {
        for reference in cleanupOwners where reference.conversationID == id && reference.owner != nil { reference.action() }
        cleanupOwners.removeAll { $0.owner == nil || $0.conversationID == id }
        for reference in stores {
            guard let store = reference.value, let context = store.context, context.route.id == id else { continue }
            markCleared(context); try? ChatMediaPreviewStore.clearCache(context: context); store.close()
        }
        if let userUID, let tenantID, let sessionID {
            let context = ChatContext(userUID: userUID, tenantID: tenantID, sessionID: sessionID, route: ChatRoute(id: id, kind: .single, title: "", avatarURL: ""))
            markCleared(context); try? ChatMediaPreviewStore.clearCache(context: context)
        }
    }

    /// 群移除成员并删除其消息时仅通知同身份同会话的打开页面。
    func removedMemberMessages(_ ids: [String], context: ChatContext) {
        guard isCurrent(context) else { return }
        contentRevisions[context.route.id] = UUID()
        try? ChatMediaPreviewStore.clearCache(context: context)
        for reference in stores where reference.value?.context == context { reference.value?.removeSenderMessages(Set(ids)) }
        for reference in cleanupOwners { (reference.owner as? ChatMediaPreviewStore)?.invalidateDeletedMessages(Set(ids), context: context) }
    }

    /// 打开的会话保留删除墓碑，媒体页不能重试已删除原条。
    func isMessageDeleted(_ message: ChatMessageRecord, context: ChatContext) -> Bool {
        guard isCurrent(context) else { return true }
        return stores.contains { reference in guard let store = reference.value, let opened = store.context, isCurrent(opened), opened.route.id == context.route.id else { return false }; return store.isMessageDeleted(message) }
    }

    /// 群昵称资料回读后同步已打开气泡，不替换已编辑的正文或墓碑。
    func updatedGroupMembers(_ members: [ChatGroupMember], context: ChatContext) {
        guard isCurrent(context) else { return }
        for reference in stores {
            guard let store = reference.value, let opened = store.context, isCurrent(opened), opened.route.kind == .group, opened.route.id == context.route.id else { continue }
            store.applyMemberMetadata(members, context: opened)
        }
    }

    /// 成员昵称同步后刷新同群设置页面，保存中的角色变化会排队回读。
    func refreshGroupSettings(groupID: String) { for reference in settings where reference.value?.snapshot?.group?.id == groupID { reference.value?.requestReload() } }

    /// 设置页面同样纳入根会话退出清理，避免群管理迟到回执。
    func makeSettingsStore() -> ChatSettingsStore {
        let store = ChatSettingsStore(client: SDKChatSettingsClient())
        settings.removeAll { $0.value == nil }; settings.append(WeakChatSettingsStore(store))
        return store
    }

    /// 根退出、切俱乐部和取消AUTH交接都应同步调用。
    func close() {
        nicknameObserver.close(); unreadObserver.close(); readCounts.deactivate()
        closedConversationContext = nil; conversationCleanupWarning = nil
        userUID = nil; tenantID = nil; sessionID = nil; revision = UUID()
        for reference in cleanupOwners where reference.owner != nil { reference.action() }; cleanupOwners.removeAll()
        for store in stores { store.value?.close() }
        stores.removeAll(); contentRevisions.removeAll()
        for store in settings { store.value?.close() }; settings.removeAll()
    }
}

private final class WeakChatStore {
    weak var value: ChatStore?
    /// 统一关闭不延长页面Store生命周期。
    init(_ value: ChatStore) { self.value = value }
}

private final class WeakChatSettingsStore {
    weak var value: ChatSettingsStore?
    /// 弱引用不延长设置页生命周期。
    init(_ value: ChatSettingsStore) { self.value = value }
}

private final class WeakChatCleanup {
    weak var owner: AnyObject?
    let conversationID: String?
    let action: @MainActor () -> Void
    /// 弱所有者避免根runtime延长媒体页面生命周期。
    init(owner: AnyObject, conversationID: String?, action: @escaping @MainActor () -> Void) { self.owner = owner; self.conversationID = conversationID; self.action = action }
}
