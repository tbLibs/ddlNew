//
//  UserInfo.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation
import ObjectMapper

/// 当前用户的业务资料；与旧项目 NoaUserModel 对应，但身份凭据单独保存。
nonisolated struct UserInfo: Mappable, Sendable {
    private(set) var userUID = ""
    private(set) var userName = ""
    private(set) var nickname = ""
    private(set) var avatar = ""
    /// 服务端约定：2 未知、1 男、0 女。
    private(set) var userSex = 2
    private(set) var nicknamePinyin = ""
    private(set) var descRemark = ""
    /// 账号状态；旧项目中 4 表示注销。
    private(set) var disableStatus = 0
    private(set) var remarks = ""
    private(set) var remarksPinyin = ""
    private(set) var showName = ""
    private(set) var yuueeAccount = ""
    private(set) var roleId = 0
    /// 0 不展示离线时间、1 展示。
    private(set) var showOfflineStatus = 0
    private(set) var hasSecurityCode = false
    private(set) var userSettings: UserSettings?

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        if map.mappingType == .fromJSON { userUID <- map["userUid"] }
        userUID <- map["userUID"]
        userName <- map["userName"]
        nickname <- map["nickname"]
        avatar <- map["avatar"]
        userSex <- map["userSex"]
        nicknamePinyin <- map["nicknamePinyin"]
        descRemark <- map["descRemark"]
        disableStatus <- map["disableStatus"]
        remarks <- map["remarks"]
        remarksPinyin <- map["remarksPinyin"]
        showName <- map["showName"]
        yuueeAccount <- map["yuueeAccount"]
        roleId <- map["roleId"]
        showOfflineStatus <- map["showOfflineStatus"]
        hasSecurityCode <- map["hasSecurityCode"]
        userSettings <- map["userSettings"]
    }
    /// 资料刷新允许部分响应，所属 UID 不一致时拒绝写入。
    func applyingProfile(_ fields: [String: Any], expectedUID: String) -> Self? {
        guard userUID == expectedUID,
              fields["userUID"] == nil || fields["userUID"] as? String == expectedUID,
              fields["userUid"] == nil || fields["userUid"] as? String == expectedUID else { return nil }
        var updates = fields
        // 资料或配置可能只下发部分字段；省略和 null 不清空旧配置，显式空字符串可以清空。
        if let settings = fields["userSettings"] as? [String: Any] {
            updates["userSettings"] = (userSettings?.toJSON() ?? [:]).merging(settings.filter { !($0.value is NSNull) }) { _, value in value }
        } else {
            updates.removeValue(forKey: "userSettings")
        }
        let merged = toJSON().merging(updates) { _, value in value }
        guard let result = Mapper<Self>().map(JSON: merged), result.userUID == expectedUID else { return nil }
        return result
    }

}
