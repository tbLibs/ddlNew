import Foundation
import CoreFoundation

enum DailySignInError: LocalizedError {
    case invalidResponse
    case message(String)
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return L10n.tr("签到数据无效，请重试")
        case .message(let text): return text
        }
    }
}

/// 服务端数字兼容数字字符串；缺字段、布尔和小数不能被当成零积分。
enum SignInPayload {
    static func object(_ value: Any) throws -> [String: Any] {
        guard let value = value as? [String: Any] else { throw DailySignInError.invalidResponse }; return value
    }
    static func integer(_ value: Any?) throws -> Int64 {
        if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() { throw DailySignInError.invalidResponse }
        guard let value, let result = Int64(String(describing: value)) else { throw DailySignInError.invalidResponse }; return result
    }
    static func rows(_ value: Any?) throws -> [[String: Any]] {
        guard let rows = value as? [[String: Any]] else { throw DailySignInError.invalidResponse }; return rows
    }
    static func flag(_ value: Any?) throws -> Bool {
        if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue }
        let number = try integer(value)
        guard number == 0 || number == 1 else { throw DailySignInError.invalidResponse }
        return number == 1
    }
    static func date(_ value: Any?) throws -> Date {
        let milliseconds = try integer(value)
        guard milliseconds > 0 else { throw DailySignInError.invalidResponse }
        return Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }
    /// 写接口已走成功回调时，缺失或坏的奖励数字不应把受理改成失败。
    static func receipt(_ value: Any) throws -> Int64? {
        if let n = value as? NSNumber, !n.boolValue { throw DailySignInError.message(L10n.tr("服务器未接受操作")) }
        if let text = value as? String, ["false", "0"].contains(text.lowercased()) { throw DailySignInError.message(L10n.tr("服务器未接受操作")) }
        guard let object = value as? [String: Any] else { return nil }
        return try? integer(object["loyalty"])
    }
}

struct SignInMonth: Equatable, Sendable {
    let year: Int
    let month: Int
    init(date: Date = Date()) {
        let parts = Self.calendar.dateComponents([.year, .month], from: date)
        year = parts.year!; month = parts.month!
    }
    static var calendar: Calendar { Calendar(identifier: .gregorian) }
    var date: Date { Self.calendar.date(from: DateComponents(year: year, month: month, day: 1))! }
    func shifted(_ amount: Int) -> Self { Self(date: Self.calendar.date(byAdding: .month, value: amount, to: date)!) }
    var fields: [String: Any] { ["year": year, "month": month] }
}

struct DailySignInInfo: Equatable {
    let signed: Bool
    let todayPoints: Int64
    let totalDays: Int64
    let totalPoints: Int64
    let monthDays: Int64
    static func parse(_ value: Any) throws -> Self {
        let d = try SignInPayload.object(value)
        return try Self(signed: SignInPayload.flag(d["isSignIn"]), todayPoints: SignInPayload.integer(d["loyalty"]), totalDays: SignInPayload.integer(d["signTotalDay"]), totalPoints: SignInPayload.integer(d["signTotalLoyalty"]), monthDays: SignInPayload.integer(d["monthTotalDay"]))
    }
}

struct DailySignInRecord: Identifiable {
    let id: Int
    let date: Date
    let points: Int64
    let dailyPoints: Int64
    let rewardPoints: Int64
}
struct DailySignInRecords {
    let total: Int64
    let rows: [DailySignInRecord]
    static func parse(_ value: Any) throws -> Self {
        let d = try SignInPayload.object(value)
        let rows = try SignInPayload.rows(d["signInRecords"]).enumerated().map { index, row in
            try DailySignInRecord(id: index, date: SignInPayload.date(row["createTime"]), points: SignInPayload.integer(row["money"]), dailyPoints: SignInPayload.integer(row["signMoneyDay"]), rewardPoints: SignInPayload.integer(row["signMoneyAway"]))
        }
        return try Self(total: SignInPayload.integer(d["totalLoyalty"]), rows: rows)
    }
}
struct DailySignInPoint: Identifiable {
    let id: Int
    let date: Date
    let points: Int64
    let type: Int64
    var title: String {
        switch type { case 9: return L10n.tr("签到"); case 18: return L10n.tr("系统扣减"); case 19: return L10n.tr("系统清除"); default: return L10n.tr("其他") }
    }
    var amount: String {
        switch type { case 9: return "+\(points.magnitude)"; case 18, 19: return "−\(points.magnitude)"; default: return String(points) }
    }
}
struct DailySignInPoints {
    let used: Int64
    let gained: Int64
    let rows: [DailySignInPoint]
    static func parse(_ value: Any) throws -> Self {
        let d = try SignInPayload.object(value)
        let rows = try SignInPayload.rows(d["integralRecordVos"]).enumerated().map { index, row in
            try DailySignInPoint(id: index, date: SignInPayload.date(row["createTime"]), points: SignInPayload.integer(row["money"]), type: SignInPayload.integer(row["opeType"]))
        }
        return try Self(used: SignInPayload.integer(d["useIntegral"]), gained: SignInPayload.integer(d["gainIntegral"]), rows: rows)
    }
}
struct DailySignInReward: Identifiable {
    let days: Int64
    let points: Int64
    var id: Int64 { days }
}
struct DailySignInRule {
    let enabled: Bool
    let mode: Int64
    let daily: Int64
    let minimum: Int64
    let maximum: Int64
    let description: String
    let rewards: [DailySignInReward]
    static func parse(_ value: Any) throws -> Self {
        let d = try SignInPayload.object(value)
        let enabled = try SignInPayload.flag(d["signInSwitch"])
        if !enabled { return Self(enabled: false, mode: 0, daily: 0, minimum: 0, maximum: 0, description: "", rewards: []) }
        let mode = try SignInPayload.integer(d["signMode"])
        guard mode == 1 || mode == 2 else { throw DailySignInError.invalidResponse }
        var rewards: [DailySignInReward] = []
        if mode == 2, let raw = d["signContinueReward"], !(raw is NSNull), String(describing: raw) != "" {
            let object: Any
            if let text = raw as? String {
                guard let bytes = text.data(using: .utf8) else { throw DailySignInError.invalidResponse }
                object = try JSONSerialization.jsonObject(with: bytes)
            } else { object = raw }
            rewards = try SignInPayload.object(object).map { key, value in
                let days = try SignInPayload.integer(key), points = try SignInPayload.integer(value)
                guard days > 0, points >= 0 else { throw DailySignInError.invalidResponse }
                return DailySignInReward(days: days, points: points)
            }.sorted { $0.days < $1.days }
        }
        return try Self(enabled: true, mode: mode, daily: mode == 2 ? SignInPayload.integer(d["signDayMoney"]) : 0,
                        minimum: mode == 1 ? SignInPayload.integer(d["signMinMoney"]) : 0,
                        maximum: mode == 1 ? SignInPayload.integer(d["signMaxMoney"]) : 0,
                        description: d[mode == 1 ? "signRandomRule" : "signContinueRule"] as? String ?? "", rewards: rewards)
    }
}

struct DailySignInReminder: Identifiable { let id: String; let date: Date }

@MainActor protocol DailySignInClient: AnyObject {
    func info(context: ChatContext) async throws -> DailySignInInfo
    func records(month: SignInMonth, context: ChatContext) async throws -> DailySignInRecords
    func points(month: SignInMonth, context: ChatContext) async throws -> DailySignInPoints
    func rule(context: ChatContext) async throws -> DailySignInRule
    func sign(context: ChatContext) async throws -> Int64?
    func reminders(sessionID: String, offset: Int, context: ChatContext) throws -> [DailySignInReminder]
    func cancel()
}
