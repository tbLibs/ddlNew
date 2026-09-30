//
//  ContactProfilePayload.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation
import ObjectMapper

/// 跨端备注变化后的好友资料响应，仅覆盖服务端实际下发的字段。
nonisolated struct ContactProfilePayload: Mappable, Sendable {
    var nickname: String?
    var nicknamePinyin: String?
    var remarksPinyin: String?
    var account: String?
    var avatar: String?
    var remarks: String?
    var description: String?
    var disableStatus: Int?

    init?(map: Map) {
        let textFields = ["nickname", "nicknamePinyin", "remarksPinyin", "userName", "avatar", "remarks", "descRemark"]
        guard (textFields + ["disableStatus"]).contains(where: { map.JSON[$0] != nil }) else { return nil }
        for field in textFields {
            if let value = map.JSON[field], !(value is String) && !(value is NSNull) { return nil }
        }
        if let status = map.JSON["disableStatus"], !(status is NSNull), Self.integerStatus(status) == nil { return nil }
    }

    mutating func mapping(map: Map) {
        nickname <- map["nickname"]
        nicknamePinyin <- map["nicknamePinyin"]
        remarksPinyin <- map["remarksPinyin"]
        account <- map["userName"]
        avatar <- map["avatar"]
        remarks <- map["remarks"]
        description <- map["descRemark"]
        disableStatus <- (map["disableStatus"], TransformOf<Int, Any>(fromJSON: { value in
            value.flatMap(Self.integerStatus)
        }, toJSON: { $0 }))
        // 缺失字段保留旧值，显式 null 表示清空备注或描述。
        if map.mappingType == .fromJSON {
            if map.JSON["remarks"] is NSNull { remarks = "" }
            if map.JSON["descRemark"] is NSNull { description = "" }
            if map.JSON["remarksPinyin"] is NSNull { remarksPinyin = "" }
        }
    }

    /// 兼容服务端的整数和整数字符串，不接受小数或对象类型。
    private static func integerStatus(_ value: Any) -> Int? {
        if let number = value as? NSNumber { return Int(number.stringValue) }
        if let text = value as? String { return Int(text) }
        return nil
    }
}
