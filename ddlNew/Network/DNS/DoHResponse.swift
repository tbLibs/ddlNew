//
//  DoHResponse.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import ObjectMapper

/// DoH JSON 响应；Answer.type 用于区分归一化阶段需要的 A 记录。
struct DoHResponse: Mappable {
    /// DNS 查询状态；0 表示成功，缺省时沿用旧接口的宽松处理。
    var status: Int?
    /// 响应中的记录列表，后续按 TXT、AAAA 或 A 类型解析。
    var answers: [Answer]?

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        status <- map["Status"]
        answers <- map["Answer"]
    }

    struct Answer: Mappable {
        /// DNS RR 类型编号，例如 A=1、TXT=16、AAAA=28。
        var type: Int?
        /// 单条记录的原始内容，可能仍需拼接或解密。
        var data = ""

        init?(map: Map) {}

        mutating func mapping(map: Map) {
            type <- map["type"]
            data <- map["data"]
        }
    }
}
