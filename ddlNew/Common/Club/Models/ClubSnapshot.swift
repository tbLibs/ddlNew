//
//  ClubSnapshot.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

/// 本地演示快照及按账号隔离的演示黑名单、举报记录。
nonisolated struct ClubSnapshot: Codable, Sendable {
    var connected = false
    var signedIn = false
    var participation: [String: Participation] = ["hike": .available, "ride": .registered, "bird": .waiting]
    // Optional for compatibility with snapshots saved before account deletion existed.
    var accountDeleted: Bool? = nil
    var localAccount: String? = nil
    var activeAccount: String? = nil
    // Optional so snapshots written by earlier app versions still decode.
    var blockedContactsByAccount: [String: Set<String>]? = nil
    var messageReports: [MessageReport]? = nil
}
