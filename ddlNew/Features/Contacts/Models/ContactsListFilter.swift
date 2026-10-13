//
//  ContactsListFilter.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 业务分组与字母分区保持独立列表。
nonisolated enum ContactsListFilter: String, CaseIterable, Identifiable, Hashable {
    case friends = "好友", friendGroups = "分组", groups = "群聊"
    var id: String { rawValue }
}
