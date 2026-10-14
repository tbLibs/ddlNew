//
//  FriendBusinessGroup.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 好友业务分组与字母索引不同；成员来自SDK库，不持有第二份关系库。
nonisolated struct FriendBusinessGroup: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let order: Int
    let isDefault: Bool
    let members: [ContactRecord]

    /// 沿用xgd的空名兜底；保留默认组重命名后的名称，不改写SDK原始字段。
    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "默认分组" : name
    }
}
