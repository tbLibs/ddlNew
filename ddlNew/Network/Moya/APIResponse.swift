//
//  APIResponse.swift
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//

import Foundation
import ObjectMapper

/// 对应返回 `Code`、`Message` 和 `Data` 的接口响应格式。
struct APIResponse<Payload: BaseMappable>: Mappable {
    var code = 0
    var message = ""
    var data: Payload?

    var isSuccess: Bool { code == 1 }

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        code <- map["Code"]
        message <- map["Message"]
        data <- map["Data"]
    }
}
