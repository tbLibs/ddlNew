//
//  ChatClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

@MainActor protocol ChatClient: AnyObject {
    /// 先读当前账号的SDK数据库，保留断网可用正文。
    func cached(context: ChatContext, offset: Int) throws -> [ChatMessageRecord]
    /// 游标补拉固定100条，由SDK签名及落库。
    func history(context: ChatContext, before: String?, offset: Int) async throws -> ChatPage
    /// 注册独立代理，回调绑定账号与会话。
    func observe(context: ChatContext, onEvent: @escaping @MainActor (ChatEvent) -> Void)
    /// 释放代理及等待中的业务请求。
    func stop()
    /// 敏感过滤在消息入队前完成，展示与真正发送正文一致。
    func prepareMessage(_ message: ChatMessageRecord, context: ChatContext) throws -> ChatMessageRecord
    /// 提交给SDK，成功入队仍然需要ACK。
    func send(_ message: ChatMessageRecord, context: ChatContext) throws
    /// 每次提交前重新读取动态角色与群状态。
    func permissions(context: ChatContext) throws -> ChatPermission
    /// 上报当前可见收到消息，语音在播放后单独调用。
    func read(_ messages: [ChatMessageRecord], context: ChatContext) async throws
    /// 草稿保存在当前账号SDK会话库，包含引用身份。
    func draft(context: ChatContext) throws -> ChatDraft
    /// 保存当前编辑版本，退出和异账号不得写入旧草稿。
    func saveDraft(_ draft: ChatDraft, context: ChatContext) throws
    /// 服务端确认后才更新本地删除撤回等状态。
    func perform(_ action: ChatMessageAction, message: ChatMessageRecord, context: ChatContext) async throws
}

extension ChatClient {
    /// 无过滤需求的测试客户端保留原文。
    func prepareMessage(_ message: ChatMessageRecord, context: ChatContext) throws -> ChatMessageRecord { message }
    /// 无草稿能力的注入客户端返回空编辑状态。
    func draft(context: ChatContext) throws -> ChatDraft { ChatDraft() }
    /// 注入客户端可按需实现草稿持久化。
    func saveDraft(_ draft: ChatDraft, context: ChatContext) throws {}
}
