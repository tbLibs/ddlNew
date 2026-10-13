//
//  ChatGroupBanRecord.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import Foundation

struct ChatGroupBanRecord: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let avatar: String
    let expires: String
    let updatedAt: String
    /// 沿旧getOvertime的超过30整天规则识别永久，空期限不猜状态。
    nonisolated var statusText: String {
        if expires == "-1" { return "永久禁言" }
        if expires.isEmpty { return "已禁言，期限以服务器为准" }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: expires), date.timeIntervalSinceNow >= 31 * 24 * 60 * 60 { return "永久禁言" }
        return "禁言至 " + expires
    }
}
