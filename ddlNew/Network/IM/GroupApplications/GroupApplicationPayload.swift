// Created by taobo on 2026/10/13.
import Foundation
import ObjectMapper

nonisolated struct GroupApplicationPayload: Mappable {
    var memreqUuid = ""
    var groupId = ""
    var userNickName = ""
    var beDesc = ""
    var beStatus = 0
    /// 仅服务器申请标识参与身份，不使用昵称作为主键。
    init?(map: Map) { guard map.JSON["memreqUuid"] != nil else { return nil } }
    /// 映射群申请的真实字段和独立状态枚举。
    mutating func mapping(map: Map) {
        memreqUuid <- map["memreqUuid"]; groupId <- map["groupId"]
        userNickName <- map["userNickName"]; beDesc <- map["beDesc"]; beStatus <- map["beStatus"]
    }
    var record: GroupApplicationRecord {
        GroupApplicationRecord(id: memreqUuid, groupID: groupId, nickname: userNickName, reason: beDesc, status: beStatus)
    }
}
