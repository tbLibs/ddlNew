//
//  MassMessageRecord.swift
//  ddlNew
//
//  Created by taobo on 2026/10/23.
//

import Foundation

nonisolated struct MassMessageRoute: Hashable { let id: String }

/// 单人和群使用复合身份，同值UID不会互相覆盖。
nonisolated struct MassMessageRecipient: Identifiable, Hashable, Sendable {
    let uid: String
    let isGroup: Bool
    var name: String
    var avatar = ""
    var error = ""
    var id: String { "\(isGroup ? 1 : 0):\(uid)" }
}

nonisolated struct MassMessageRecord: Identifiable, Sendable {
    let id: String
    let labelID: String
    let label: String
    let sentAt: String
    let type: Int
    let status: Int
    let total: Int
    let errors: Int
    let body: [String: String]
    var summary: String {
        switch type { case 0: return body["content"] ?? ""; case 1: return "[图片]"; case 2: return "[视频]"; case 5: return body["name"] ?? "[文件]"; default: return "暂不支持的消息类型" }
    }
    var statusText: String {
        switch status { case 1: return "发送中"; case 2: return errors > 0 ? "部分发送失败" : "发送完成"; case 3: return "发送失败"; default: return "状态待更新" }
    }
}

nonisolated struct MassMessagePage<Value: Sendable>: Sendable {
    let records: [Value]
    let total: Int?
    func hasMore(page: Int) -> Bool { !records.isEmpty && (total.map { page * 15 < $0 } ?? (records.count == 15)) }
}

/// 旧端body既可能是JSON字符串，也可能已经解码为对象；非法整页不能冒充空列表。
nonisolated enum MassMessagePayload {
    static func string(_ value: Any?) -> String {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return ""
    }
    static func integer(_ value: Any?) -> Int? { Int(string(value)) }
    static func object(_ value: Any?) -> [String: Any]? {
        if let value = value as? [String: Any] { return value }
        if let value = value as? String, let data = value.data(using: .utf8) { return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] }
        return nil
    }
    static func records(_ value: Any?) throws -> MassMessagePage<MassMessageRecord> {
        guard let json = object(value), let rows = json["records"] as? [[String: Any]] else { throw MassMessageError.invalidResponse }
        let records = try rows.map { row -> MassMessageRecord in
            let id = string(row["id"] ?? row["taskId"]), labelID = string(row["labelId"])
            guard !id.isEmpty, !labelID.isEmpty, let type = integer(row["mtype"]), let body = object(row["body"]) else { throw MassMessageError.invalidResponse }
            return MassMessageRecord(id: id, labelID: labelID, label: string(row["label"]), sentAt: string(row["sendTime"]), type: type,
                status: integer(row["status"]) ?? 0, total: max(0, integer(row["totalCount"]) ?? 0), errors: max(0, integer(row["errorCount"]) ?? 0),
                body: body.mapValues { string($0) })
        }
        return MassMessagePage(records: records, total: integer(json["total"]))
    }
    static func recipients(_ value: Any?, failures: Bool) throws -> MassMessagePage<MassMessageRecipient> {
        guard let json = object(value), let rows = json["records"] as? [[String: Any]] else { throw MassMessageError.invalidResponse }
        let records = try rows.map { row -> MassMessageRecipient in
            let uid = string(row[failures ? "errorUserUid" : "memberUid"])
            guard !uid.isEmpty, let type = integer(row["chatType"]), [0, 1].contains(type) else { throw MassMessageError.invalidResponse }
            return MassMessageRecipient(uid: uid, isGroup: type == 1, name: uid, error: failures ? string(row["errorMsg"]) : "")
        }
        return MassMessagePage(records: records, total: integer(json["total"]))
    }
    /// 标签16个UTF16单位沿用旧端上限，避免截断组合字符。
    static func validate(text: String, label: String, recipients: [MassMessageRecipient], reusing: String?, type: Int) throws {
        guard reusing?.isEmpty == false || !recipients.isEmpty else { throw MassMessageError.message("请先选择接收对象") }
        guard label.utf16.count <= 16 else { throw MassMessageError.message("标签最多16个字符") }
        guard [0, 1, 2, 5].contains(type) else { throw MassMessageError.message("此消息类型暂不支持群发") }
        if type == 0 && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw MassMessageError.message("请输入群发内容") }
    }
}

nonisolated enum MassMessageError: LocalizedError {
    case invalidResponse, sessionExpired, message(String)
    var errorDescription: String? {
        switch self { case .invalidResponse: return "群发响应无效，请重试"; case .sessionExpired: return "登录状态已变化，请重新进入群发助手"; case .message(let value): return value }
    }
}

@MainActor protocol MassMessageClient: AnyObject {
    func load(page: Int) async throws -> MassMessagePage<MassMessageRecord>
    func recipients(record: MassMessageRecord, failures: Bool, page: Int) async throws -> MassMessagePage<MassMessageRecipient>
    func create(label: String, recipients: [MassMessageRecipient]) async throws -> String
    func send(labelID: String, type: Int, body: String) async throws
    func delete(_ record: MassMessageRecord) async throws
    func cancel()
}
