//
//  ChatGroupDetail.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

struct ChatGroupDetail: Equatable, Sendable {
    let id: String
    var name: String
    var avatar: String
    var role: Int
    var isActive: Bool
    var nickname: String
    var isAllMuted: Bool
    var isPrivateChat: Bool
    var requiresApproval: Bool
    var historyVisible: Bool
    var qrVisible: Bool
    var remindEnabled: Bool
    var memberCount: Int
    var members: [ChatGroupMember] = []
    var isNetCall = false
    var membersSyncReady = false
    var bannedMembers: [ChatGroupBanRecord] = []
    var isPersonallyMuted = false
}
