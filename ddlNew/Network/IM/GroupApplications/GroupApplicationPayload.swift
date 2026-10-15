// Created by taobo on 2026/10/13.
import Foundation
import CoreFoundation
import ObjectMapper

nonisolated struct GroupApplicationPayload: Mappable {
    var memreqUuid = ""
    var groupId = ""
    var userNickName = ""
    var beDesc = ""
    var beStatus = 0
    var beInviteUserId = ""
    var beInviteNickname = ""
    var beUserAvatarFileName = ""
    var userUid = ""
    var userAvatarFileName = ""
    var roleId = 0

    /// 必须有真实申请、群标识与状态；缺失数据不能被ObjectMapper静默丢掉。
    init?(map: Map) {
        guard Self.identifier(map.JSON["memreqUuid"]) != nil,
              Self.identifier(map.JSON["groupId"]) != nil,
              Self.integer(map.JSON["beStatus"]) != nil else { return nil }
    }

    /// 旧响应数字与字符串混用，昵称和双方UID分别保存，不通过姓名推断身份。
    mutating func mapping(map: Map) {
        memreqUuid = Self.identifier(map.JSON["memreqUuid"]) ?? ""
        groupId = Self.identifier(map.JSON["groupId"]) ?? ""
        beStatus = Self.integer(map.JSON["beStatus"]) ?? 0
        userNickName = map.JSON["userNickName"] as? String ?? ""
        beDesc = map.JSON["beDesc"] as? String ?? ""
        beInviteUserId = Self.identifier(map.JSON["beInviteUserId"]) ?? ""
        beInviteNickname = map.JSON["beInviteNickname"] as? String ?? ""
        beUserAvatarFileName = map.JSON["beUserAvatarFileName"] as? String ?? ""
        userUid = Self.identifier(map.JSON["userUid"]) ?? ""
        userAvatarFileName = map.JSON["userAvatarFileName"] as? String ?? ""
        roleId = Self.integer(map.JSON["roleId"]) ?? 0
    }

    /// 申请标识不作用户UID；缺少可选身份时界面保留文案但关闭资料入口。
    var record: GroupApplicationRecord {
        GroupApplicationRecord(id: memreqUuid, groupID: groupId, nickname: userNickName, reason: beDesc,
            status: beStatus, inviterID: beInviteUserId, inviterNickname: beInviteNickname,
            inviterAvatar: beUserAvatarFileName, inviteeID: userUid, inviteeAvatar: userAvatarFileName, roleID: roleId)
    }

    /// 标识兼容整数JSON，排除布尔与小数，避免大整数经过Double丢精度。
    static func identifier(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              var decimal = Decimal(string: number.stringValue) else { return nil }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &decimal, 0, .plain)
        guard rounded == decimal else { return nil }
        return NSDecimalNumber(decimal: decimal).stringValue
    }

    /// 状态与总数只接受整数，非法值不回退到可操作的待审核状态。
    static func integer(_ value: Any?) -> Int? {
        guard let string = identifier(value) else { return nil }
        return Int(string)
    }
}
