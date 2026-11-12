//
//  ClubSnapshot.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

/// 本地演示账号快照；旧 JSON 中已经移除的字段由解码器忽略。
nonisolated struct ClubSnapshot: Codable, Sendable {
    var connected = false
    var signedIn = false
    // Optional for compatibility with snapshots saved before account deletion existed.
    var accountDeleted: Bool? = nil
    var localAccount: String? = nil
    var activeAccount: String? = nil
}
