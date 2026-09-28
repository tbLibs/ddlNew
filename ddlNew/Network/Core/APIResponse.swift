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
    /// 业务码，当前接口以 1 表示成功。
    var code = 0
    /// 服务端返回的业务提示。
    var message = ""
    /// 使用 ObjectMapper 映射后的业务数据。
    var data: Payload?

    /// 不等同于 HTTP 2xx，仅表示业务码成功。
    var isSuccess: Bool { code == 1 }

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        code <- map["Code"]
        message <- map["Message"]
        data <- map["Data"]
    }
}
