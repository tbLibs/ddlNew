//
//  FriendApplicationRecord.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 真实好友申请摘要；隐藏键包含发送时间，使重新申请可以再次显示。
nonisolated struct FriendApplicationRecord: Identifiable, Equatable, Sendable {
    let id: String
    let hashKey: String
    let sendTime: String
    let fromUID: String
    let targetUID: String
    let fromNickname: String
    let targetNickname: String
    var fromAvatar: String = ""
    var targetAvatar: String = ""
    let status: Int
    var fromDisableStatus: Int = 0
    var targetDisableStatus: Int = 0
    var source: Int = 1
    var fromRoleID: Int = 0
    var targetRoleID: Int = 0
    /// 只允许对方待处理申请接受；旧协议没有拒绝状态。
    func action(for userUID: String) -> FriendApplicationAction {
        let disabled = userUID == fromUID ? targetDisableStatus : fromDisableStatus
        if disabled == 4 { return .unavailable }
        if status == 1 { return .accepted }
        if status == 2 { return userUID == fromUID ? .reapply : .expired }
        guard status == 0 else { return .unavailable }
        return userUID == fromUID ? .waiting : .accept
    }
    /// 申请摘要只用于头像展示，接受后仍需完整好友接口落库。
    func displayContact(for userUID: String) -> ContactRecord {
        ContactRecord(id: peerID(for: userUID), nickname: name(for: userUID), avatar: avatar(for: userUID),
                      disableStatus: userUID == fromUID ? targetDisableStatus : fromDisableStatus, roleID: roleID(for: userUID))
    }

    /// 从当前用户视角选择对方角色，名称仍由真实角色配置提供。
    func roleID(for userUID: String) -> Int { userUID == fromUID ? targetRoleID : fromRoleID }

    /// 依据当前登录身份返回对方UID，禁止将申请人固定当目标。
    func peerID(for userUID: String) -> String { userUID == fromUID ? targetUID : fromUID }
    /// 从双方摘要选择对方名称。
    func name(for userUID: String) -> String { userUID == fromUID ? targetNickname : fromNickname }
    /// 从双方摘要选择对方头像。
    func avatar(for userUID: String) -> String { userUID == fromUID ? targetAvatar : fromAvatar }
}

nonisolated enum FriendApplicationAction: Sendable { case accept, waiting, accepted, expired, reapply, unavailable }
