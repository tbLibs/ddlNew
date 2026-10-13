//
//  ChatActionPolicy.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

enum ChatMessageAction: String, CaseIterable, Sendable {
    case copy, reply, delete, deleteBoth, recall, edit, select, forward, pin
}

enum ChatActionPolicy {
    /// 只展示当前消息身份、类型、成功状态与动态权限允许的动作。
    nonisolated static func allowed(for message: ChatMessageRecord, userUID: String, permission: ChatPermission, now: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> Set<ChatMessageAction> {
        guard message.isBody, message.isCompatible, permission.isActive else { return [] }
        var result: Set<ChatMessageAction> = []
        let text = [0, 10].contains(message.type)
        if text { result.insert(.copy) }
        if permission.canDelete { result.insert(.delete) }
        guard message.state == .sent, !message.serverID.isEmpty else { return result }
        if [0, 1, 2, 3, 4, 5, 6, 7, 10, 12, 18, 21].contains(message.type) && permission.canSend { result.insert(.reply) }
        let own = message.senderID == userUID
        if permission.canDeleteBoth && (own || permission.isGroup && [1, 2].contains(permission.role)) { result.insert(.deleteBoth) }
        let elapsed = max(0, (TimeInterval(now) - TimeInterval(message.timestamp)) / 1000)
        // 管理员撤回低角色成员的消息没有本人时限；本人消息仍按服务器窗口判断。
        if own {
            if permission.canRecall, let window = permission.recallWindow,
               window > 0 && elapsed <= window { result.insert(.recall) }
        } else if permission.isGroup && permission.canRecallOthers && [1, 2].contains(permission.role),
                  message.senderRole.map({ [0, 1].contains($0) && $0 < permission.role }) == true {
            result.insert(.recall)
        }
        if own && text && permission.canSend && permission.canEdit, let window = permission.editWindow,
           window > 0 && elapsed <= window { result.insert(.edit) }
        if ![6, 16, 18, 20, 21, 1000].contains(message.type) {
            result.formUnion([.select, .forward])
        }
        if text && message.referenceID.isEmpty && permission.canPin { result.insert(.pin) }
        return result
    }
}
