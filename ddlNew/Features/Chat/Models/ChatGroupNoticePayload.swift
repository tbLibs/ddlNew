//
//  ChatGroupNoticePayload.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import Foundation

/// 公告列表与详情使用同一响应映射，写入字段独立于读取字段。
enum ChatGroupNoticePayload {
    /// xgd读取content和topStatus；status仅是正常/删除状态，不能当置顶开关。
    nonisolated static func notice(from row: [String: Any], fallback: ChatGroupNotice? = nil) throws -> ChatGroupNotice {
        let id = scalar(row["noticeId"]) ?? fallback?.id ?? ""
        guard !id.isEmpty,
              let content = (row["content"] ?? row["noticeContent"]) as? String else { throw ChatClientError.invalidResponse }
        if let fallback, fallback.id != id { throw ChatClientError.invalidResponse }
        let top = row["topStatus"] ?? row["isTop"]
        let pinned: Bool
        if let top, !(top is NSNull) {
            switch scalar(top)?.lowercased() {
            case "1", "true": pinned = true
            case "0", "false": pinned = false
            default: throw ChatClientError.invalidResponse
            }
        } else { pinned = false }
        return ChatGroupNotice(id: id, content: content,
            author: row["noticeCreateNickname"] as? String ?? row["nickName"] as? String ?? fallback?.author ?? "",
            timestamp: scalar(row["createTime"]) ?? fallback?.timestamp ?? "", pinned: pinned)
    }

    /// 损坏非空页报错，不把缺正文或坏ID默认为空白公告或静默丢行。
    nonisolated static func notices(from json: [String: Any]) throws -> [ChatGroupNotice] {
        guard let rows = json["rows"] as? [[String: Any]] else { throw ChatClientError.invalidResponse }
        return try rows.map { try notice(from: $0) }
    }

    /// ID和毫秒时间兼容字符串/整数，保留NSNumber十进制表示，避免精度和空时间丢失。
    nonisolated private static func scalar(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        return (value as? NSNumber)?.stringValue
    }

    /// 沿用xgd写入的正文、置顶和发送群消息参数，不把状态字段作为写参数。
    nonisolated static func saveParameters(notice: ChatGroupNotice?, content: String, pinned: Bool, sendMessage: Bool, groupID: String, userUID: String) -> [String: Any] {
        var values: [String: Any] = ["groupId": groupID, "userUid": userUID, "noticeContent": content, "isTop": pinned ? "1" : "0", "isSendMsg": sendMessage ? "1" : "0", "translateContent": ""]
        if let notice { values["noticeId"] = notice.id }
        return values
    }
}
