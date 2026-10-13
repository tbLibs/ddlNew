//
//  GroupRecord.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 群列表值快照；管理页另读实时详情，不能依赖列表权限提交操作。
nonisolated struct GroupRecord: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let avatar: String
    let role: Int
    let memberCount: Int
    var isNeedVerify: Bool = false
    var isShowQRCode: Bool = false
    var isPrivateChat: Bool = false
    var isAllMuted: Bool = false
}
