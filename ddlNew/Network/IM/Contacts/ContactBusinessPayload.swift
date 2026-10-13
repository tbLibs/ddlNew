//
//  ContactBusinessPayload.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import CoreFoundation
import ObjectMapper

/// SDK业务响应沿用ObjectMapper，只在网络边界解析混合类型字段。
nonisolated struct ContactBusinessPayload: Mappable {
    var fields: [String: Any] = [:]
    /// 保存响应字典，强制业务标识与字段在转换时校验。
    init?(map: Map) { fields = map.JSON }
    /// 此类型仅用于入站响应，不持久化任意服务端JSON。
    mutating func mapping(map: Map) { fields = map.JSON }
    /// 兼容服务端文本与数值标识，不将字典转换成展示字符串。
    func text(_ key: String) -> String {
        if let value = fields[key] as? String { return value }
        if let value = fields[key] as? NSNumber { return value.stringValue }
        return ""
    }
    /// 整数混合类型的缺省值由每个业务调用明确选择。
    func integer(_ key: String, default fallback: Int = 0) -> Int { Int(text(key)) ?? fallback }
    /// 服务端布尔字段兼容0/1及true/false。
    func flag(_ key: String) -> Bool { ["1", "true"].contains(text(key).lowercased()) }
    /// 映射用户资料且保留调用方确认的稳定目标UID。
    func contact(fallbackID: String = "", cached: ContactRecord? = nil) -> ContactRecord? {
        let identifiers = ["userUid", "uid", "friendUserUID"]
        let strings = ["userName", "nickname", "remarks", "descRemark", "avatar", "nicknamePinyin", "remarksPinyin"]
        let integers = ["disableStatus", "userType", "roleId"]
        guard (identifiers + strings + integers + ["onlineStatus"]).contains(where: { fields[$0] != nil }) else { return nil }
        for key in strings {
            if let value = fields[key], !(value is String) && !(value is NSNull) { return nil }
        }
        for key in integers {
            if let value = fields[key], strictInteger(value) == nil { return nil }
        }
        if let status = fields["onlineStatus"], strictBoolean(status) == nil { return nil }
        var suppliedIDs: [String] = []
        for key in identifiers {
            guard let value = fields[key] else { continue }
            guard (value is String || strictInteger(value) != nil), !text(key).isEmpty else { return nil }
            suppliedIDs.append(text(key))
        }
        guard Set(suppliedIDs).count <= 1 else { return nil }
        let uid = suppliedIDs.first ?? fallbackID
        guard !uid.isEmpty else { return nil }
        return ContactRecord(id: uid,
            account: fields["userName"] == nil ? cached?.account ?? "" : text("userName"),
            nickname: fields["nickname"] == nil ? cached?.nickname ?? "" : text("nickname"),
            remarks: fields["remarks"] == nil ? cached?.remarks ?? "" : text("remarks"),
            description: fields["descRemark"] == nil ? cached?.description ?? "" : text("descRemark"),
            avatar: fields["avatar"] == nil ? cached?.avatar ?? "" : text("avatar"),
            isOnline: fields["onlineStatus"] == nil ? cached?.isOnline ?? false : flag("onlineStatus"),
            disableStatus: fields["disableStatus"] == nil ? cached?.disableStatus ?? 0 : integer("disableStatus"),
            userType: fields["userType"] == nil ? cached?.userType ?? 0 : integer("userType"),
            nicknamePinyin: fields["nicknamePinyin"] == nil && fields["nickname"] == nil ? cached?.nicknamePinyin ?? "" : text("nicknamePinyin"),
            remarksPinyin: fields["remarksPinyin"] == nil && fields["remarks"] == nil ? cached?.remarksPinyin ?? "" : text("remarksPinyin"),
            roleID: fields["roleId"] == nil ? cached?.roleID ?? 0 : integer("roleId"))
    }
    /// 状态只接受整数或整数字符串，布尔、空值和小数不能降级成正常状态。
    private func strictInteger(_ value: Any) -> Int? {
        if let number = value as? NSNumber {
            guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            return Int(number.stringValue)
        }
        if let string = value as? String { return Int(string) }
        return nil
    }

    /// 在线字段只接受明确的0/1或true/false，不将任意类型当离线。
    private func strictBoolean(_ value: Any) -> Bool? {
        if let number = value as? NSNumber {
            if number.doubleValue == 0 { return false }
            if number.doubleValue == 1 { return true }
            return nil
        }
        if let string = value as? String {
            if ["1", "true"].contains(string.lowercased()) { return true }
            if ["0", "false"].contains(string.lowercased()) { return false }
        }
        return nil
    }

    /// 申请身份由hashKey和发送时间构成，双方字段均保留供当前用户视角选择。
    func application() -> FriendApplicationRecord? {
        let hash = text("hashKey"), time = text("sendTime"), from = text("fromUserUid"), target = text("beUserUid")
        guard !hash.isEmpty, !from.isEmpty, !target.isEmpty else { return nil }
        return FriendApplicationRecord(id: "\(hash)-\(time)", hashKey: hash, sendTime: time, fromUID: from, targetUID: target, fromNickname: text("nickname"), targetNickname: text("beUserNickname"), fromAvatar: text("fromUserAvatar"), targetAvatar: text("beUserAvatar"), status: integer("beStatus", default: -1), fromDisableStatus: integer("fromDisableStatus"), targetDisableStatus: integer("beDisableStatus"), source: integer("friendAddType"), fromRoleID: integer("fromRoleId"), targetRoleID: integer("beRoleId"))
    }
}
