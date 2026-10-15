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

    /// 读取权限需有真实在群、个人禁言及全群禁言结果，空回执不能确认可发送。
    static func verified(detail: [String: Any], mute: [String: Any]) -> Bool {
        boolean(detail["userInGroup"]) != nil && boolean(mute["isGroupForbid"]) != nil && boolean(mute["isGroupChat"]) != nil
    }
}
