import Foundation

nonisolated enum ReportReason: String, CaseIterable, Codable, Sendable, Identifiable {
    case harassment = "骚扰辱骂"
    case spam = "垃圾广告"
    case fraud = "诈骗诱导"
    case privacy = "泄露隐私"
    case inappropriate = "不当内容"
    case other = "其他"

    var id: Self { self }
}

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
