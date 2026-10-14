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

    /// 部分群缓存可能人数为0；仅保留已确认人数，其余资料仍取最新快照。
    func preservingKnownMemberCount(from previous: GroupRecord?) -> GroupRecord {
        guard memberCount <= 0, let previous, previous.memberCount > 0 else { return self }
        return GroupRecord(id: id, name: name, avatar: avatar, role: role, memberCount: previous.memberCount,
                           isNeedVerify: isNeedVerify, isShowQRCode: isShowQRCode,
                           isPrivateChat: isPrivateChat, isAllMuted: isAllMuted)
    }
}
