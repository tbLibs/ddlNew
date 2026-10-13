//
//  SDKChatNicknameObserver.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import Foundation
import NoaChatCore

/// 公开Socket消息协议代理保留原处理器，补充当前SDK未fanout的GroupMemberNick。
nonisolated private final class SDKChatNicknameProxy: SDKChatMessageForwarder, NoaMessageDelegate, @unchecked Sendable {}

@MainActor final class SDKChatNicknameObserver {
    private var proxy: SDKChatNicknameProxy?
    private var generation = UUID()
    private var tasks: [String: Task<Void, Never>] = [:]
    private var queue = ChatGroupRefreshQueue()

    /// SDK构造时已设置原delegate，AUTH后安装一次；重连不轮询争夺代理。
    func activate(userUID: String, tenantID: String, sessionID: UUID) {
        close()
        let socket = NoaIMSocketManagerTool.sharedManager()
        guard let original = socket.messageDelegate as? NSObject else { return }
        let run = generation
        let proxy = SDKChatNicknameProxy(original: original) { [weak self] object in
            guard let message = object as? IMServerMessage, message.sMsgType.rawValue == 2,
                  message.synchroMessage.synchroType.rawValue == 15, message.synchroMessage.cType.rawValue == 1,
                  !message.synchroMessage.sessionId.isEmpty else { return }
            let value = ChatGroupNicknameSync(groupID: message.synchroMessage.sessionId, senderID: message.from, nickname: message.synchroMessage.content)
            Task { @MainActor [weak self] in
                guard let self, self.generation == run,
                      let context = ChatRuntime.shared.context(for: ChatRoute(id: value.groupID, kind: .group, title: "", avatarURL: "")),
                      context.userUID == userUID, context.tenantID == tenantID, context.sessionID == sessionID else { return }
                self.enqueue(value, context: context, run: run)
            }
        }
        self.proxy = proxy; socket.messageDelegate = proxy
    }

    /// 昵称事件按群合并等待，群A未完成时群B不会取消A。
    private func enqueue(_ value: ChatGroupNicknameSync, context: ChatContext, run: UUID) {
        guard queue.begin(value.groupID) else { return }
        tasks[value.groupID] = Task {
            repeat {
                await refresh(value, context: context, run: run)
                guard generation == run, !Task.isCancelled, ChatRuntime.shared.isCurrent(context) else { return }
                if !queue.finish(value.groupID) { break }
            } while queue.begin(value.groupID)
            tasks[value.groupID] = nil
        }
    }

    /// 协议内容仅作变化信号，真实姓名、备注和角色从当前群API重新获取并落SDK。
    private func refresh(_ value: ChatGroupNicknameSync, context: ChatContext, run: UUID) async {
        let client = SDKChatSettingsClient(); defer { client.close() }
        do {
            _ = try await client.load(context: context)
            guard generation == run, !Task.isCancelled, ChatRuntime.shared.isCurrent(context) else { return }
            ChatRuntime.shared.refreshGroupSettings(groupID: value.groupID)
        } catch { /* 重连后群资料会再次回读；失败不使用协议昵称覆盖备注或伪造名单。 */ }
    }

    /// 退出仅在当前Socket代理仍属本观察器时还原原SDK，不能覆盖新AUTH所有者。
    func close() {
        generation = UUID(); for task in tasks.values { task.cancel() }; tasks.removeAll(); queue = ChatGroupRefreshQueue()
        let socket = NoaIMSocketManagerTool.sharedManager()
        if let proxy, (socket.messageDelegate as AnyObject?) === proxy { socket.messageDelegate = proxy.original as? NoaMessageDelegate }
        proxy = nil
    }
}
