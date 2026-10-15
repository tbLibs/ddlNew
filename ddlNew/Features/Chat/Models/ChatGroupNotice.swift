//
//  ChatGroupNotice.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

struct ChatGroupNotice: Identifiable, Equatable, Sendable {
    let id: String
    var content: String
    var author: String
    var timestamp: String
    var pinned: Bool

    /// 沿xgd公告列表和详情的毫秒时间格式，缺失或损坏时间不显示原始数字。
    func displayTimestamp(timeZone: TimeZone = .current) -> String {
        guard let milliseconds = Int64(timestamp), milliseconds > 0 else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: Double(milliseconds) / 1000))
    }
}
