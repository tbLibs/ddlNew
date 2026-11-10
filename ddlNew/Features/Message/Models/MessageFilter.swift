//
//  MessageFilter.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

enum MessageFilter: String, CaseIterable, Identifiable {
    var displayName: String { L10n.lookup(rawValue) }
    case all = "全部", unread = "未读", notices = "通知"
    var id: Self { self }
}
