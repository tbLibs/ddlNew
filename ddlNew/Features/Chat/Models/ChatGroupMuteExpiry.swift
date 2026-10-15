//
//  ChatGroupMuteExpiry.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import Foundation

/// 到期只安排服务端重查，时间本身不解除禁言。
nonisolated struct ChatGroupMuteExpiry: Equatable, Sendable {
    let signature: String
    let deadline: Date

    /// 旧接口时间沿用本地时区与固定格式，非法或倒置区间不猜到期。
    static func decode(_ json: [String: Any], timeZone: TimeZone = .current) -> ChatGroupMuteExpiry? {
        guard ChatGroupPermissionPayload.boolean(json["isGroupForbid"]) == true,
              let start = json["startTime"] as? String, let end = json["endTime"] as? String else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone; formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"; formatter.isLenient = false
        guard let startDate = formatter.date(from: start), let endDate = formatter.date(from: end),
              formatter.string(from: startDate) == start, formatter.string(from: endDate) == end,
              endDate >= startDate else { return nil }
        return ChatGroupMuteExpiry(signature: start + "|" + end, deadline: endDate)
    }
}

/// 已经过期却仍被服务端禁言的同一时间窗只自动重查一次，避免请求自旋。
nonisolated struct ChatGroupMuteExpiryState: Sendable {
    private(set) var checkedSignature: String?

    /// 未来的新截止时间继续计时；相同已查过期窗口保持等待权限事件或前台重查。
    func plan(_ expiry: ChatGroupMuteExpiry?, now: Date) -> ChatGroupMuteExpiry? {
        guard let expiry, expiry.deadline > now || expiry.signature != checkedSignature else { return nil }
        return expiry
    }

    /// 无论网络成功或失败都消费这次自动到期检查，失败仍保留原禁言快照。
    mutating func checked(_ expiry: ChatGroupMuteExpiry) { checkedSignature = expiry.signature }
}
