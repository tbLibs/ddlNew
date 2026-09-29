//
//  RememberedLoginCredentials.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import ObjectMapper

/// 仅用于登录表单回填，整份记录保存在 Keychain，不属于已认证会话。
nonisolated struct RememberedLoginCredentials: Mappable, Sendable {
    private(set) var account = ""
    private(set) var password = ""
    /// 避免更换俱乐部后回填另一俱乐部的账号密码。
    private(set) var lastLiceseId = ""

    init(account: String, password: String, lastLiceseId: String) {
        self.account = account
        self.password = password
        self.lastLiceseId = lastLiceseId
    }

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        account <- map["account"]
        password <- map["password"]
        lastLiceseId <- map["lastLiceseId"]
    }

    var isValid: Bool { !account.isEmpty && !password.isEmpty && !lastLiceseId.isEmpty }
}
