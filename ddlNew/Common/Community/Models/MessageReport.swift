//
//  MessageReport.swift
//  ddlNew
//
//  Created by taobo on 2026/10/12.
//

import Foundation

nonisolated struct MessageReport: Codable, Sendable, Identifiable {
    let id: UUID
    let accountKey: String
    let conversationID: String
    let messageID: String
    let sourceTitle: String
    let messageText: String
    let reason: ReportReason
    let details: String
    let createdAt: Date
}
