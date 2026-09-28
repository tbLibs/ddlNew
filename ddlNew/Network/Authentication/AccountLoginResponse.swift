//
//  AccountLoginResponse.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation
import ObjectMapper

/// SDK 已解开业务响应外层；这里只映射登录成功的 data，不持久化用户会话。
nonisolated struct AccountLoginResponse: Mappable, Sendable {
    /// 服务端用户主键，对应旧项目 NoaUserModel.userUID。
    private(set) var userUID = ""
    private(set) var userName = ""
    private(set) var nickname = ""
    private(set) var avatar = ""
    /// 身份凭据只临时留在内存，本步骤不写入 AppStorage。
    private(set) var token = ""
    /// V5 登录返回的设备凭据；本步骤尚未接入保存和装载。
    private(set) var deviceSecret = ""

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        userUID <- map["userUID"]
        userName <- map["userName"]
        nickname <- map["nickname"]
        avatar <- map["avatar"]
        token <- map["token"]
        deviceSecret <- map["deviceSecret"]
    }

    /// 不能仅凭成功回调就把空数据当作有效登录结果。
    var isValid: Bool { !userUID.isEmpty && !token.isEmpty }
}
