//
//  ChatPinStatus.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

struct ChatPinStatus: Equatable, Sendable {
    let global: Bool
    let personal: Bool
    /// 旧type1全局、2个人、3两者，0未置顶；未知值不可当已授权状态。
    init?(type: Int) { guard (0...3).contains(type) else { return nil }; global = type == 1 || type == 3; personal = type == 2 || type == 3 }
}
