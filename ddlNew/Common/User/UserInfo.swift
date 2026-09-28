//
//  UserInfo.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

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

    init?(map: Map) {}

    mutating func mapping(map: Map) {
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
    }
}
