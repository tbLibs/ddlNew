//
//  PasswordSecurityRequirement.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import ObjectMapper

/// 只保存已确认的强制要求所属身份，不包含密码、密钥或会话凭据。
nonisolated struct PasswordSecurityRequirement: Mappable, Sendable {
    private(set) var userUID = ""
    private(set) var lastLiceseId = ""

    init(userUID: String, lastLiceseId: String) {
        self.userUID = userUID
        self.lastLiceseId = lastLiceseId
    }
    init?(map: Map) {}
    mutating func mapping(map: Map) {
        userUID <- map["userUID"]
        lastLiceseId <- map["lastLiceseId"]
    }
    var isValid: Bool { !userUID.isEmpty && !lastLiceseId.isEmpty }
    func matches(userUID: String, lastLiceseId: String) -> Bool {
        self.userUID == userUID && self.lastLiceseId == lastLiceseId
    }
}
