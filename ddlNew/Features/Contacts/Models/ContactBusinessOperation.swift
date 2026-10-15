//
//  ContactBusinessOperation.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 请求枚举明确操作范围，好友申请不提供没有真实协议的拒绝动作。
nonisolated enum ContactBusinessOperation: Equatable, Sendable {
    case search(String)
    case blackState(String)
    case blacklist
    case setBlack(friendID: String, blocked: Bool)
    case profile(String)
    case profileAfterAcceptance(String)
    case groupAccess(String)
    case groupNickname(groupID: String, userUID: String)
    case applications(page: Int)
    case unreadApplications
    case roleLabels
    case apply(friendID: String)
    case accept(friendID: String)
    case setRemark(friendID: String, remark: String, description: String)
    case deleteFriend(String)
    case groups
    case createGroup(name: String)
    case renameGroup(id: String, name: String)
    case reorderGroup(id: String, order: Int)
    case deleteGroup(id: String)
    case moveFriend(friendID: String, groupID: String)
    case qrCode(groupID: String?)
    case decodeQR(String)
    case joinGroup(id: String, inviter: String, reason: String)
}
