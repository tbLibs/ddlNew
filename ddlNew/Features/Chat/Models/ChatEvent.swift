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
    case memberHistoryDeleted([String])
    case memberMetadataRefresh
    case memberMetadataChanged([ChatGroupMember])
    case refresh, cleared, permissionsChanged, pinsChanged
}

struct ChatPage: Sendable {
    let messages: [ChatMessageRecord]
    let hasMore: Bool
}
