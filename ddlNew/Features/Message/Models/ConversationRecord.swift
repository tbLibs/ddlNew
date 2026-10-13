//
//  ConversationRecord.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation

nonisolated enum ConversationKind: Hashable, Sendable {
    case single, group, massMessage, systemMessage, signInReminder, paymentAssistant
}

struct ConversationRecord: Identifiable, Sendable {
    let id: String
    let title: String
    let avatarURL: String
    let kind: ConversationKind
    let preview: String
    let latestTime: Date?
    let unreadCount: Int
    let isMarkedUnread: Bool
    let isPinned: Bool
    let isMuted: Bool
    let isDraft: Bool
}

enum ConversationsChange: Sendable {
    case syncStarted
    case changed
    case syncFinished
    case syncFailed(String)
}

@MainActor
protocol ConversationsClient: AnyObject {
    /// AUTH前绑定用户，并将SDK同步事件转换为刷新信号。
    func observe(for userUID: String, _ onChange: @escaping @MainActor (ConversationsChange) -> Void)
    /// 登出释放订阅，旧事件不能影响下一登录轮次。
    func stopObserving()
    /// 读取当前用户数据库中的完整会话快照。
    func loadConversations(for userUID: String) async throws -> [ConversationRecord]
}

/// SDK 查询只按最新时间返回；这里按会话 ID 去重，再将置顶会话排在前面。
enum ConversationSorter {
    /// 合并同步与本地副本，使用时间及稳定 ID 保持可预测排序。
    nonisolated static func sorted(_ records: [ConversationRecord]) -> [ConversationRecord] {
        var unique: [String: ConversationRecord] = [:]
        for record in records where !record.id.isEmpty {
            if let old = unique[record.id],
               (old.latestTime ?? .distantPast) > (record.latestTime ?? .distantPast) { continue }
            unique[record.id] = record
        }
        return unique.values.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.latestTime != rhs.latestTime { return (lhs.latestTime ?? .distantPast) > (rhs.latestTime ?? .distantPast) }
            return lhs.id > rhs.id
        }
    }
}

/// Tab 角标只统计当前可见会话；免打扰不计入，手动标记未读计 1。
enum ConversationUnread {
    /// 只统计可见且未免打扰的会话。
    nonisolated static func total(_ records: [ConversationRecord]) -> Int {
        records.reduce(0) { total, item in
            total + (item.isMuted ? 0 : item.unreadCount + (item.isMarkedUnread ? 1 : 0))
        }
    }
}
