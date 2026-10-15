//
//  ChatVisibleReadPolicy.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import Foundation

/// 可见已读只改变实际收到的未读正文，会话计数不代替正文阅读状态。
nonisolated enum ChatVisibleReadPolicy {
    /// 按服务端身份去重，拒绝自己、其他会话、已读与非正文输入。
    static func candidates(_ messages: [ChatMessageRecord], userUID: String, conversationID: String) -> [ChatMessageRecord] {
        var seen = Set<String>()
        return messages.filter {
            $0.conversationID == conversationID && !$0.senderID.isEmpty && $0.senderID != userUID &&
            $0.isBody && !$0.isRead && !$0.serverID.isEmpty && seen.insert($0.serverID).inserted
        }
    }

    /// 旧type13数组存SID_发送UID_原客户端MID，缺失任一真实身份不能只发SID或补造ID。
    static func wireEntry(_ message: ChatMessageRecord) -> String? {
        guard !message.serverID.isEmpty, !message.senderID.isEmpty, !message.localID.isEmpty else { return nil }
        // 与旧NSString拼接完全一致；保留字段自身下划线，不另做拆分或转义。
        return message.serverID + "_" + message.senderID + "_" + message.localID
    }

    /// 仅扣实际写库成功且从未读转读的去重条数，保留屏外及等待期间的新消息。
    static func remainingUnread(_ current: Int, transitionedIDs: Set<String>) -> Int {
        max(0, max(0, current) - transitionedIDs.count)
    }

}

/// 消息正文写入与会话计数写入分开成功时，保留已转读身份直到计数确认保存。
nonisolated struct ChatVisibleReadTransitions: Sendable {
    private(set) var pendingIDs = Set<String>()

    /// 只有实际正文写入成功的稳定服务端ID进入待扣集合，重试不重复累计。
    mutating func saved(_ serverID: String) { if !serverID.isEmpty { pendingIDs.insert(serverID) } }

    /// 会话写失败保留集合，再次进入或可见读重试仍使用最新计数扣减。
    func remainingUnread(_ current: Int) -> Int { ChatVisibleReadPolicy.remainingUnread(current, transitionedIDs: pendingIDs) }

    /// 计数实际写入成功后才消费；会话退出由客户端整体重置，不能迁到另一账号。
    mutating func committed() { pendingIDs.removeAll() }
}
