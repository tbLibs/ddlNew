//
//  GroupMemberPickerFilter.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 选人候选来源共用同一份UID选择状态。
nonisolated enum GroupMemberPickerFilter: String, CaseIterable, Identifiable {
    var displayName: String { L10n.lookup(rawValue) }
    case all = "好友", recent = "最近", groups = "分组"
    var id: String { rawValue }
}
