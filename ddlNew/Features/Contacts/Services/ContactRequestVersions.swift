//
//  ContactRequestVersions.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation

/// 同一好友只接收最后一次资料请求，防止乱序响应恢复旧备注。
nonisolated struct ContactRequestVersions {
    private var latest: [String: UUID] = [:]

    mutating func begin(for friendUID: String) -> UUID {
        let version = UUID()
        latest[friendUID] = version
        return version
    }

    func accepts(_ version: UUID, for friendUID: String) -> Bool { latest[friendUID] == version }

    mutating func finish(_ version: UUID, for friendUID: String) {
        if accepts(version, for: friendUID) { latest.removeValue(forKey: friendUID) }
    }
}
