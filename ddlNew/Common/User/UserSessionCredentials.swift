//
//  UserSessionCredentials.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import ObjectMapper

/// Keychain 内的当前会话凭据；不包含密码、加密密钥或密码密文。
nonisolated struct UserSessionCredentials: Mappable, Sendable {
    private(set) var userUID = ""
    private(set) var token = ""
    private(set) var deviceSecret = ""
    /// 设备凭据只供同一俱乐部、同一登录账号使用。
    private(set) var loginInfo = ""
    private(set) var lastLiceseId = ""

    init(userUID: String, token: String, deviceSecret: String, loginInfo: String, lastLiceseId: String) {
        self.userUID = userUID
        self.token = token
        self.deviceSecret = deviceSecret
        self.loginInfo = loginInfo
        self.lastLiceseId = lastLiceseId
    }

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        userUID <- map["userUID"]
        token <- map["token"]
        deviceSecret <- map["deviceSecret"]
        loginInfo <- map["loginInfo"]
        lastLiceseId <- map["lastLiceseId"]
    }

    var isValid: Bool { !userUID.isEmpty && !token.isEmpty && !loginInfo.isEmpty && !lastLiceseId.isEmpty }

    func replacingToken(_ token: String) -> Self {
        Self(userUID: userUID, token: token, deviceSecret: deviceSecret,
             loginInfo: loginInfo, lastLiceseId: lastLiceseId)
    }
}
