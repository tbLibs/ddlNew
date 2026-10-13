//
//  UserRoleAuthority.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import ObjectMapper

/// 对应旧项目角色开关，缺失字段沿用旧端默认值。
nonisolated struct UserRoleAuthority: Mappable, Sendable {
    private(set) var values: [String: String] = [:]
    private(set) var configurationData: [String: String] = [:]
    private(set) var authorityKeys: [String: String] = [:]
    static let keys = ["allowAddFriend", "createGroup", "deleteMessage", "remoteDeleteMessage",
                       "groupHairAssistant", "groupSecurity", "showGroupPersonNum", "showHeadLogo",
                       "showRoleName", "upFile", "showTeam", "upImageVideoFile", "showUserRead",
                       "isShowFileAssistant", "translation_switch", "group_msg_pinning",
                       "user_dialog_msg_pinning", "edited_message_sent"]
    /// 映射器初始化，字段缺失时由具体权限规则提供默认值。
    init?(map: Map) {}
    /// 保留开关、数值限制与配置数据，支持持久化往返。
    mutating func mapping(map: Map) {
        if map.mappingType == .fromJSON {
            for key in Self.keys {
                if let entry = map.JSON[key] as? [String: Any] {
                    // 配额等限制数据与权限标识也要保留，后续功能读取同一份角色快照。
                    configurationData[key] = entry["configData"] as? String ?? (entry["configData"] as? NSNumber)?.stringValue
                    authorityKeys[key] = entry["authorityKey"] as? String
                    if let text = entry["configValue"] as? String { values[key] = text }
                    else if let number = entry["configValue"] as? NSNumber { values[key] = number.stringValue }
                    else if entry["configValue"] == nil || entry["configValue"] is NSNull { values[key] = "" }
                    else { values[key] = "false" }
                } else if map.JSON[key] != nil {
                    // 条目结构损坏应关闭权限，不能冒充整个字段缺失而套用开启默认值。
                    values[key] = "false"
                }
            }
        } else {
            for key in Self.keys {
                let entry = ["configValue": values[key] ?? (defaultAllowed(key) ? "true" : "false"),
                             "configData": configurationData[key] ?? "", "authorityKey": authorityKeys[key] ?? ""]
                entry >>> map[key]
            }
        }
    }
    /// 开关只接受明确开启值，时长权限应使用 positiveMinutes。
    func allows(_ key: String) -> Bool {
        guard Self.keys.contains(key) else { return false }
        guard let value = values[key], !value.isEmpty else { return defaultAllowed(key) }
        return ["1", "true", "yes"].contains(value.lowercased())
    }
    /// 编辑时限单位为分钟，未知、无效或非正数一律关闭。
    func positiveMinutes(_ key: String) -> Int {
        guard Self.keys.contains(key), let raw = values[key], let value = Int(raw), value > 0 else { return 0 }
        return value
    }
    /// 按旧端约定处理缺失权限，显式损坏不应用宽松默认。
    private func defaultAllowed(_ key: String) -> Bool {
        // 图片视频上传仅缺失时开启；翻译空值也默认开启。
        key == "translation_switch" || (key == "upImageVideoFile" && values[key] == nil)
    }
}
