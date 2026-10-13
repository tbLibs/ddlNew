//
//  ChatSettingsClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

struct ChatSettingsSnapshot: Sendable {
    let isPinned: Bool
    let isMuted: Bool
    let canClear: Bool
    let group: ChatGroupDetail?
}

@MainActor protocol ChatSettingsClient: AnyObject {
    /// 群角色或策略事件通知设置Store回读最新快照。
    func observe(_ changed: @escaping @MainActor () -> Void)
    /// 服务端刷新群身份，本地读取会话设置。
    func load(context: ChatContext) async throws -> ChatSettingsSnapshot
    /// 服务端成功后才回读置顶或免打扰。
    func setConversation(context: ChatContext, pinned: Bool?, muted: Bool?) async throws
    /// 指定范围清空，删除会话与退出群均另走各自接口。
    func clear(context: ChatContext) async throws
    /// 群管理每次提交前获取最新身份和目标角色。
    func groupAction(_ action: ChatGroupAction, context: ChatContext) async throws
    /// 退出释放设置页面的SDK代理和等待。
    func close()
}

extension ChatSettingsClient {
    /// 注入客户端可选择实现同步事件。
    func observe(_ changed: @escaping @MainActor () -> Void) {}
}
