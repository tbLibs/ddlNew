//
//  ChatACKNormalizer.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

enum ChatACKNormalizer {
    /// ACK信封ID和连接轮次不能当作原消息ID或业务会话ID。
    nonisolated static func event(envelopeID: String, acknowledgedID: String, serverID: String, timestamp: Int64) -> ChatEvent? {
        guard !acknowledgedID.isEmpty, !serverID.isEmpty else { return nil }
        return .ack(localID: acknowledgedID, serverID: serverID, timestamp: timestamp)
    }
}
