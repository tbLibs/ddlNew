//
//  ChatGroupPermissionPayload.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import Foundation

/// 群权限只接受明确布尔值，未知标量不因NSNumber.boolValue被放行。
nonisolated enum ChatGroupPermissionPayload {
    /// SDK响应兼容字符串和数字0/1，非法值由调用方按业务边界保守处理。
    static func boolean(_ value: Any?) -> Bool? {
        if let number = value as? NSNumber {
            if number == 0 { return false }
            if number == 1 { return true }
            return nil
        }
        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true": return true
            case "0", "false": return false
            default: return nil
            }
        }
        return nil
    }

    /// 旧端个人未禁言时可省略此键；明确null或非法值仍不能当成未禁言。
    static func personalMuted(_ mute: [String: Any]) -> Bool? {
        guard let value = mute["isGroupForbid"] else { return false }
        return boolean(value)
    }

    /// 调试仅保留固定权限字段的形状；原始响应、身份及认证信息均不输出。
    static func diagnostic(detail: [String: Any], mute: [String: Any]) -> String {
        func state(_ value: Any?) -> String {
            guard let value else { return "missing" }
            if value is NSNull { return "null" }
            if let flag = boolean(value) { return flag ? "true" : "false" }
            return "invalid"
        }
        return "detail.userInGroup=" + state(detail["userInGroup"])
            + " mute.isGroupForbid=" + state(mute["isGroupForbid"])
            + " mute.isGroupChat=" + state(mute["isGroupChat"])
    }

    /// 在群和全员禁言必须明确，个人禁言按旧接口缺省规则；空回执仍不可发送。
    static func verified(detail: [String: Any], mute: [String: Any]) -> Bool {
        boolean(detail["userInGroup"]) != nil && personalMuted(mute) != nil && boolean(mute["isGroupChat"]) != nil
    }
}
