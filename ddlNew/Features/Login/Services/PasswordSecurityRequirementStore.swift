//
//  PasswordSecurityRequirementStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import SwiftUI
import ObjectMapper

@MainActor
protocol PasswordSecurityRequirementStoring {
    func load() -> PasswordSecurityRequirement?
    func save(userUID: String, lastLiceseId: String)
    func clear(userUID: String?, lastLiceseId: String?)
}

/// AppStorage 沿用唯一记录策略；登录时按 UID 和俱乐部核对，不能锁住其他账号。
@MainActor
final class PasswordSecurityRequirementStore: PasswordSecurityRequirementStoring {
    static let shared = PasswordSecurityRequirementStore()
    @AppStorage(loginForcedPasswordRequirementAppStorageKey) private var json = ""

    init(defaults: UserDefaults = .standard) {
        _json = AppStorage(wrappedValue: "", loginForcedPasswordRequirementAppStorageKey, store: defaults)
    }

    func load() -> PasswordSecurityRequirement? {
        guard !json.isEmpty, let value = Mapper<PasswordSecurityRequirement>().map(JSONString: json), value.isValid else { return nil }
        return value
    }

    func save(userUID: String, lastLiceseId: String) {
        let requirement = PasswordSecurityRequirement(userUID: userUID, lastLiceseId: lastLiceseId)
        guard requirement.isValid, let encoded = Mapper<PasswordSecurityRequirement>().toJSONString(requirement) else { return }
        json = encoded
    }

    func clear(userUID: String?, lastLiceseId: String?) {
        // 无运行时身份的明确退出也需清除启动缓存；存在身份时只删除其本人的要求。
        if let userUID, let lastLiceseId,
           let requirement = load(), !requirement.matches(userUID: userUID, lastLiceseId: lastLiceseId) { return }
        json = ""
    }
}
