//
//  ChatGroupMemberPage.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import CoreFoundation

enum ChatGroupMemberPage {
    /// 真实分页使用items，兼容旧rows；损坏页必须报错，不能当作已同步空群。
    static func rows(from data: [String: Any]) throws -> [[String: Any]] {
        let payload = data["items"] ?? data["rows"]
        guard let rows = payload as? [[String: Any]] else {
            throw ChatClientError.unavailable("群成员数据格式异常，请刷新后重试")
        }
        return try rows.map { row in
            var normalized = row
            let id: String
            if let value = row["userUid"] as? String { id = value.trimmingCharacters(in: .whitespacesAndNewlines) }
            else if let value = row["userUid"] as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
                    value.stringValue.range(of: "^[0-9]+$", options: .regularExpression) != nil { id = value.stringValue }
            else { throw ChatClientError.unavailable("群成员身份数据异常，请刷新后重试") }
            guard !id.isEmpty else { throw ChatClientError.unavailable("群成员身份数据异常，请刷新后重试") }
            normalized["userUid"] = id
            return normalized
        }
    }
}
