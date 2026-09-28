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
    private(set) var userInfo: UserInfo?
    var userUID: String { userInfo?.userUID ?? "" }
    var userName: String { userInfo?.userName ?? "" }
    var nickname: String { userInfo?.nickname ?? "" }
    var avatar: String { userInfo?.avatar ?? "" }
    /// 登录成功后交给会话存储写 Keychain，不混入普通用户资料。
    private(set) var token = ""
    /// V5 登录返回的设备凭据，可能未下发。
    private(set) var deviceSecret = ""

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        if map.mappingType == .fromJSON {
            userInfo = Mapper<UserInfo>().map(JSON: map.JSON)
        } else {
            userInfo?.mapping(map: map)
        }
        token <- map["token"]
        deviceSecret <- map["deviceSecret"]
    }

    /// 不能仅凭成功回调就把空数据当作有效登录结果。
    var isValid: Bool { !userUID.isEmpty && !token.isEmpty }
}
