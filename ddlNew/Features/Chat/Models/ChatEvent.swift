//
//  ChatEvent.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

enum ChatEvent: Sendable {
    case upsert(ChatMessageRecord)
    case ack(localID: String, serverID: String, timestamp: Int64)
    case failed(localID: String, reason: ChatFailureReason)
    /// 106业务拒收可以晚于传输ACK到达，与网络超时失败分开处理。
    case blacklistRejected(localID: String, reason: ChatFailureReason)
    case memberHistoryDeleted([String])
    case memberMetadataRefresh
    case memberMetadataChanged([ChatGroupMember])
    case refresh, cleared, permissionsChanged, pinsChanged
}

struct ChatPage: Sendable {
    let messages: [ChatMessageRecord]
    let hasMore: Bool
    /// 控制消息可能不生成可见行，分页进度必须保留原始远端游标与本机偏移。
    let nextCursor: String?
    let nextOffset: Int?
    /// 服务端明确恢复且请求期间未变更的旧本机状态；普通缓存页不携带此资格。
    let restoredServerIDs: Set<String>

    init(messages: [ChatMessageRecord], hasMore: Bool, nextCursor: String? = nil, nextOffset: Int? = nil, restoredServerIDs: Set<String> = []) {
        self.messages = messages; self.hasMore = hasMore
        self.nextCursor = nextCursor; self.nextOffset = nextOffset
        self.restoredServerIDs = restoredServerIDs
    }
}
