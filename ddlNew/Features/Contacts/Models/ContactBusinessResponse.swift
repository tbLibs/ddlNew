//
//  ContactBusinessResponse.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 网络层输出值快照，页面不持有SDK对象或任意JSON。
nonisolated struct ContactBusinessResponse: Sendable {
    var success: Bool = true
    var contacts: [ContactRecord] = []
    var applications: [FriendApplicationRecord] = []
    var unreadVersions: [String: String] = [:]
    var roleLabels: [Int: String] = [:]
    var groups: [FriendBusinessGroup] = []
    /// 资料读取或备注保存确认后的SDK缓存快照，保存失败不提供新快照。
    var profile: ContactRecord?
    var isFriend: Bool = false
    var canAccessProfile: Bool = false
    var groupNickname: String?
    var hasMore: Bool = false
    var qrCode: String = ""
    var expiry: String = ""
    var qrTarget: BusinessQRTarget?
}

nonisolated enum BusinessQRTarget: Equatable, Sendable {
    case user(id: String)
    case group(id: String, name: String, avatar: String, inviter: String, isMember: Bool, needsApproval: Bool)
}
