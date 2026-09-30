//
//  ClubSnapshot.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation

/// 俱乐部本地展示快照，不作为真实登录或 AUTH 成功的依据。
nonisolated struct ClubSnapshot: Codable, Sendable {
    var connected = false
    var signedIn = false
    var participation: [String: Participation] = ["hike": .available, "ride": .registered, "bird": .waiting]
    // 可选字段用于读取引入注销功能前保存的本地快照。
    var accountDeleted: Bool? = nil
}
