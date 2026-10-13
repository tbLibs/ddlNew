//
//  ChatSettingsStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import Combine

@MainActor final class ChatSettingsStore: ObservableObject {
    @Published private(set) var snapshot: ChatSettingsSnapshot?
    @Published private(set) var busy = false
    @Published var errorMessage: String?
    @Published private(set) var hasLeft = false
    private let client: any ChatSettingsClient
    private var context: ChatContext?
    private var generation = UUID()
    private var pendingReload = false

    /// 注入客户端测试迟到角色与群操作回执。
    init(client: any ChatSettingsClient) { self.client = client }

    /// 设置页身份始终来自已认证runtime，页面取消使旧请求失效。
    func open(_ context: ChatContext) async {
        if self.context == context { return }
        close(); self.context = context
        let run = generation
        client.observe { [weak self] in
            guard let self, self.generation == run else { return }
            self.requestReload()
        }
        await reload()
    }

    /// 外部群昵称或角色事件不能丢弃保存期间的刷新需求。
    func requestReload() { if busy { pendingReload = true } else { Task { await reload() } } }

    /// 刷新失败保留已有设置供只读查看，不伪造成功开关。
    func reload() async {
        guard let context, !busy else { return }
        let run = generation; busy = true
        defer { if generation == run { busy = false; drainPendingReload() } }
        do { let value = try await client.load(context: context); if generation == run { snapshot = value; if value.group?.isActive == false { hasLeft = true } } }
        catch { if generation == run { errorMessage = error.localizedDescription } }
    }

    /// 置顶和免打扰必须服务端成功并回读，失败仍显示原值。
    func setConversation(pinned: Bool? = nil, muted: Bool? = nil) async {
        await operate { context in try await self.client.setConversation(context: context, pinned: pinned, muted: muted) }
    }

    /// 清空需页面明确确认，Store再次复核当前清空资格。
    func clear() async {
        guard snapshot?.canClear == true else { errorMessage = "当前账号不允许清空记录"; return }
        await operate { try await self.client.clear(context: $0) }
    }

    /// 管理动作完成后回读最新群资料；本人离开则关闭页面。
    @discardableResult func groupAction(_ action: ChatGroupAction) async -> Bool {
        guard let detail = snapshot?.group, let context,
              ChatGroupPolicy.permits(action, detail: detail, userUID: context.userUID) else { errorMessage = "当前群权限不允许此操作"; return false }
        if case .nickname(let value) = action, value.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count > 30 { errorMessage = "群昵称最多30字"; return false }
        if case .rename(let value) = action, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errorMessage = "群名称不能为空"; return false }
        return await operate { context in
            try await self.client.groupAction(action, context: context)
            if self.context == context, action == .leave || action == .dissolve { self.hasLeft = true }
        }
    }

    /// 所有写操作共用去重和登录轮次守卫，成功回读而非直接改快照。
    @discardableResult private func operate(_ work: (ChatContext) async throws -> Void) async -> Bool {
        guard let context, !busy else { return false }
        let run = generation; busy = true; errorMessage = nil
        defer { if generation == run { busy = false; drainPendingReload() } }
        do {
            try await work(context)
            guard generation == run, !Task.isCancelled else { return false }
            if hasLeft { return true }
            do {
                let value = try await client.load(context: context)
                guard generation == run, !Task.isCancelled else { return false }; snapshot = value
            } catch { if generation == run { errorMessage = "服务器已受理操作，刷新资料失败：" + error.localizedDescription } }
            return generation == run && !Task.isCancelled
        } catch { if generation == run { errorMessage = error.localizedDescription }; return false }
    }

    /// 写操作或长成员分页期间的角色事件不能丢失，结束后回读最新快照。
    private func drainPendingReload() {
        guard pendingReload, context != nil else { return }; pendingReload = false
        Task { await reload() }
    }

    /// 设置页进入共用Store的子页时保留状态，真正离开父页才结束观察。
    func leaveSettingsView(presentingChild: Bool) { if !presentingChild { close() } }

    /// 退出只清当前设置等待，其他聊天与群列表保留各自所有权。
    func close() { generation = UUID(); client.close(); context = nil; snapshot = nil; busy = false; hasLeft = false; errorMessage = nil; pendingReload = false }
}
