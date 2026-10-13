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
}
