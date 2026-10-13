//
//  SDKChatDelegate.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore

nonisolated final class SDKChatDelegate: NSObject, NoaToolMessageDelegate, CIMToolGroupDelegate, NoaToolUserDelegate, @unchecked Sendable {
    private let userUID: String
    private let conversationID: String
    private let sourceGroupID: String?
    private var notification: NSObjectProtocol?
    private let changed: @Sendable (ChatEvent) -> Void

    /// 代理固定本轮身份，回调转成Sendable消息值。
    init(userUID: String, conversationID: String, sourceGroupID: String? = nil, changed: @escaping @Sendable (ChatEvent) -> Void) {
        self.userUID = userUID; self.conversationID = conversationID; self.sourceGroupID = sourceGroupID; self.changed = changed
        notification = NotificationCenter.default.addObserver(forName: Notification.Name("GroupDeleteMemberHistoryNotification"), object: nil, queue: nil) { notification in
            guard notification.userInfo?["gid"] as? String == conversationID, let ids = notification.userInfo?["deleteMemberUidList"] as? [String], !ids.isEmpty else { return }
            changed(.memberHistoryDeleted(ids))
        }
    }
    /// 释放通知观察者，关闭聊天后不继续接其他账号的群历史删除。
    deinit { if let notification { NotificationCenter.default.removeObserver(notification) } }

    /// 普通正文与SDK合并后的消息更新使用同一映射。
    func cimToolChatMessageReceive(_ message: NoaIMChatMessageModel) { publish(message) }
    /// 已读、撤回和删除由SDK原条状态更新反映。
    func cimToolChatMessageUpdate(_ message: NoaIMChatMessageModel) { publish(message) }
    /// 编辑事件更新原消息，不新增独立编辑气泡。
    func cimToolEditChatMessageUpdate(_ message: NoaIMChatMessageModel) { publish(message) }
    /// ACK含真实双ID与服务器发送时间，空ID在Store拒绝。
    func cimToolChatMessageSendSuccess(_ messageACK: IMChatMessageACK) {
        // sessionId是Socket连接UUID，业务会话由Store中的原本地ID定位。
        if let event = ChatACKNormalizer.event(envelopeID: messageACK.msgId, acknowledgedID: messageACK.ackMsgId, serverID: messageACK.sMsgId, timestamp: messageACK.sendTime) { changed(event) }
    }
    /// 带分类失败优先映射结构化原因，不暴露底层响应。
    func cimToolChatMessageSendFail(_ messageID: String, reason: CIMMessageSendFailureReason) { changed(.failed(localID: messageID, reason: SDKChatMessageMapper.failure(Int(reason.rawValue)) ?? .unknown)) }
    /// 兼容旧SDK无分类回调，Store不会覆盖有效ACK。
    func cimToolChatMessageSendFail(_ messageID: String) { changed(.failed(localID: messageID, reason: .unknown)) }
    /// 全清事件仅影响对应会话。
    func cimToolMessageDeleteAll(_ sessionID: String) { if sessionID == conversationID { changed(.cleared) } }
    /// 最新消息同步完成后读取本轮SDK库。
    func imSdkChatMessage(forSessionSyncFinish sessionID: String) { if sessionID == conversationID { changed(.refresh) } }
    /// 动态角色变化重新计算发送和消息动作。
    func imSdkChatMessageUpdateUserRoleAuthority() { changed(.permissionsChanged) }
    /// SDK好友删除后重新计算单聊资格，不能继续使用已删除关系发送。
    func imSdkUserFriendDelete(_ friendDeleteModel: LingIMFriendModel) { if friendDeleteModel.friendUserUID == conversationID { changed(.permissionsChanged) } }
    /// 好友关系恢复或资料变更时使用当前SDK库再计算资格。
    func imSdkUserFriendAdd(_ friendAddModel: LingIMFriendModel) { if friendAddModel.friendUserUID == conversationID { changed(.permissionsChanged) } }
    /// 好友删除协议事件可能先于完整资料同步，立即发权限回读信号。
    func cimToolUserFriendDelete(_ message: FriendDelMessage) { changed(.permissionsChanged) }

    /// 群禁言、角色与失效变化不作为普通文本插入。
    func cimToolGroupUpdate(with model: LingIMGroupModel) { if (model.groupId == conversationID || model.groupId == sourceGroupID) { changed(.permissionsChanged) } }
    /// 群被删除立即使发送资格失效。
    func cimToolGroupDelete(with model: LingIMGroupModel) { if (model.groupId == conversationID || model.groupId == sourceGroupID) { changed(.permissionsChanged) } }
    /// 只转发归属于本轮会话的消息。
    private func publish(_ model: NoaIMChatMessageModel) {
        let record = SDKChatMessageMapper.record(model, userUID: userUID)
        if let server = model.serverMessage {
            let kind = Int(server.sMsgType.rawValue)
            if kind == 221 { for event in ChatGroupEventPolicy.events(kind: kind, groupID: server.groupSingleForbidMessage.gid, conversationID: conversationID) { changed(event) } }
            if kind == 204, let kick = server.kickGroupMessage { for event in ChatGroupEventPolicy.events(kind: kind, groupID: kick.gid, conversationID: conversationID, removedIDs: [kick.uid], deletesHistory: kick.msgDel) { changed(event) } }
        }
        if record.conversationID == conversationID { changed(.upsert(record)) }
    }
}
