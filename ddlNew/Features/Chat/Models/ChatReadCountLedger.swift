//
//  ChatReadCountLedger.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//
import Foundation

nonisolated struct ChatReadCountOwner: Hashable, Sendable {
    let userUID: String
    let tenantID: String
    let sessionID: UUID
    func matches(_ context: ChatContext) -> Bool {
        userUID == context.userUID && tenantID == context.tenantID && sessionID == context.sessionID
    }
}

nonisolated struct ChatReadCountConversation: Hashable, Sendable {
    let id: String
    let kind: ConversationKind
    init(_ route: ChatRoute) { id = route.id; kind = route.kind }
}

nonisolated struct ChatReadCountPlan: Sendable {
    fileprivate let owner: ChatReadCountOwner
    fileprivate let conversation: ChatReadCountConversation
    fileprivate let epoch: UUID
    let ids: Set<String>
    let remaining: Int
}

nonisolated struct ChatReadCountClearCheckpoint: Sendable {
    fileprivate let owner: ChatReadCountOwner
    fileprivate let conversation: ChatReadCountConversation
    fileprivate let boundaryID: String
    fileprivate let membersAtRequest: Set<String>
}

/// 仅保存计数来源和待扣身份，不另建聊天数据库；未知历史false不等于参与会话计数。
nonisolated struct ChatReadCountLedger: Sendable {
    private struct State: Sendable {
        var epoch = UUID()
        var count: Int?
        var boundaryID = ""
        var members = Set<String>()
        var pending = Set<String>()
        var written = Set<String>()
        var seen = Set<String>()
        var excluded = Set<String>()
    }
    private var owner: ChatReadCountOwner?
    private var states: [ChatReadCountConversation: State] = [:]

    /// AUTH所有者更换时撤销旧身份，页面退出不调用此方法。
    mutating func activate(userUID: String, tenantID: String, sessionID: UUID) {
        owner = ChatReadCountOwner(userUID: userUID, tenantID: tenantID, sessionID: sessionID); states.removeAll()
    }
    mutating func deactivate() { owner = nil; states.removeAll() }

    /// SDK归零或外部减少计数会开启新epoch，旧待扣债不能扣到后续新消息。
    mutating func observe(context: ChatContext, count: Int, latestID: String) {
        guard owner?.matches(context) == true else { return }
        let key = ChatReadCountConversation(context.route)
        var state = states[key] ?? State(); let count = max(0, count)
        if count == 0 || state.count.map({ count < $0 }) == true {
            state.epoch = UUID(); state.excluded.formUnion(state.members)
            state.members.removeAll(); state.pending.removeAll(); state.written.removeAll()
            if count == 0, !latestID.isEmpty, state.boundaryID.isEmpty || !Self.atOrBefore(latestID, boundary: state.boundaryID) { state.boundaryID = latestID }
        }
        state.count = count; states[key] = state
    }

    /// 权威会话分页会替换计数，成员身份没有一并返回；旧债不得用于这个新计数。
    mutating func authoritative(context: ChatContext, count: Int, latestID: String) {
        guard owner?.matches(context) == true else { return }
        let key = ChatReadCountConversation(context.route); var state = states[key] ?? State()
        state.epoch = UUID(); state.excluded.formUnion(state.members)
        state.members.removeAll(); state.pending.removeAll(); state.written.removeAll()
        state.count = max(0, count)
        if count == 0, !latestID.isEmpty, state.boundaryID.isEmpty || !Self.atOrBefore(latestID, boundary: state.boundaryID) { state.boundaryID = latestID }
        states[key] = state
    }

    /// 只接SDK真实receive且其已落库会话快照指向该条消息；历史/编辑更新不能补造资格。
    mutating func received(_ id: String, context: ChatContext, count: Int, latestID: String) {
        observe(context: context, count: count, latestID: latestID)
        guard owner?.matches(context) == true, count > 0, !id.isEmpty, id == latestID else { return }
        let key = ChatReadCountConversation(context.route); var state = states[key] ?? State()
        guard !state.seen.contains(id), !state.excluded.contains(id), !Self.atOrBefore(id, boundary: state.boundaryID) else { return }
        state.seen.insert(id); state.members.insert(id)
        if state.written.contains(id) { state.pending.insert(id) }
        states[key] = state
    }

    /// 只有实际正文写true成功、且属于当前计数的身份进入待扣集合。
    @discardableResult mutating func saved(_ id: String, context: ChatContext) -> Bool {
        guard owner?.matches(context) == true else { return false }
        let key = ChatReadCountConversation(context.route)
        guard !id.isEmpty else { return false }
        var state = states[key] ?? State(); state.written.insert(id)
        let counted = state.members.contains(id)
        if counted { state.pending.insert(id) }
        states[key] = state; return counted
    }

    /// 无会话记录且无已知债务是新聊天的正常状态，不制造计数保存错误。
    func hasPending(context: ChatContext) -> Bool {
        guard owner?.matches(context) == true, let state = states[ChatReadCountConversation(context.route)] else { return false }
        return !state.pending.intersection(state.members).isEmpty
    }

    /// 每次补扣读取SDK最新计数；初始非零未知部分保持，不从最新N条历史猜计数成员。
    mutating func plan(context: ChatContext, count: Int, latestID: String) -> ChatReadCountPlan? {
        observe(context: context, count: count, latestID: latestID)
        let key = ChatReadCountConversation(context.route)
        guard let owner, owner.matches(context), let state = states[key] else { return nil }
        let ids = state.pending.intersection(state.members)
        guard !ids.isEmpty else { return nil }
        return ChatReadCountPlan(owner: owner, conversation: key, epoch: state.epoch, ids: ids, remaining: max(0, max(0, count) - ids.count))
    }

    /// 会话计数实际写入成功后才消费计划；页面close/reopen和旧epoch回执都不误消费。
    mutating func commit(_ plan: ChatReadCountPlan, context: ChatContext) {
        guard owner == plan.owner, plan.owner.matches(context), ChatReadCountConversation(context.route) == plan.conversation,
              var state = states[plan.conversation], state.epoch == plan.epoch else { return }
        state.pending.subtract(plan.ids); state.members.subtract(plan.ids); state.written.subtract(plan.ids); state.count = plan.remaining
        states[plan.conversation] = state
    }

    /// 全清请求冻结真实起点SID和当时成员；等待期间新到达的身份不随旧请求删除。
    func beginClear(context: ChatContext, boundaryID: String) -> ChatReadCountClearCheckpoint? {
        guard let owner, owner.matches(context) else { return nil }
        let key = ChatReadCountConversation(context.route)
        return ChatReadCountClearCheckpoint(owner: owner, conversation: key, boundaryID: boundaryID, membersAtRequest: states[key]?.members ?? [])
    }

    /// 采用本应用成功请求的边界，不使用会被SDK重连推进的clearReadNumSMsgIdDict。
    mutating func confirmClear(_ checkpoint: ChatReadCountClearCheckpoint, context: ChatContext, count: Int?, latestID: String) {
        guard owner == checkpoint.owner, checkpoint.owner.matches(context), ChatReadCountConversation(context.route) == checkpoint.conversation else { return }
        let key = checkpoint.conversation; var state = states[key] ?? State()
        let removed = state.members.filter { checkpoint.membersAtRequest.contains($0) || Self.atOrBefore($0, boundary: checkpoint.boundaryID) }
        state.epoch = UUID(); state.excluded.formUnion(removed); state.members.subtract(removed); state.pending.subtract(removed)
        state.written = state.written.filter { !checkpoint.membersAtRequest.contains($0) && !Self.atOrBefore($0, boundary: checkpoint.boundaryID) }
        if state.boundaryID.isEmpty || !Self.atOrBefore(checkpoint.boundaryID, boundary: state.boundaryID) { state.boundaryID = checkpoint.boundaryID }; state.count = count.map { max(0, $0) }; states[key] = state
        if count == 0 { observe(context: context, count: 0, latestID: latestID) }
    }

    /// SDK的服务端SID按十进制递增使用；不透明ID仅能确认完全相同，不猜字符串顺序。
    private static func atOrBefore(_ id: String, boundary: String) -> Bool {
        guard !boundary.isEmpty else { return false }
        if id == boundary { return true }
        guard !id.isEmpty, id.utf8.allSatisfy({ (48...57).contains($0) }), boundary.utf8.allSatisfy({ (48...57).contains($0) }) else { return false }
        let value = String(id.drop(while: { $0 == "0" })); let limit = String(boundary.drop(while: { $0 == "0" }))
        return value.count == limit.count ? value <= limit : value.count < limit.count
    }
}

/// SDK回调只携带标识与计数，防止跨线程持有可变数据库模型。
nonisolated struct ChatReadCountSnapshot: Sendable {
    let id: String
    let kind: ConversationKind
    var count: Int
    let latestID: String
}
nonisolated enum ChatReadCountEvent: Sendable {
    case counter(ChatReadCountSnapshot)
    case authoritative(ChatReadCountSnapshot)
    case received(ChatMessageRecord, ChatReadCountSnapshot)
}
