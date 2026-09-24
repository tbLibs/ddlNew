//
//  SystemConfigRecord.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation
import ObjectMapper

/// 老项目 NoaSystemSettingModel 中登录前需要的字段；不缓存音视频等服务端密钥。
nonisolated struct SystemConfigRecord: Mappable {
    /// 1～7 对应账号、邮箱、手机号及其组合。
    var loginMethod = ""
    /// 注册入口支持的方式。
    var registerMethod = ""
    /// 后续业务请求的租户验签字段。
    var tenantCode = ""
    /// 1：关闭；2：图形；3：腾讯；4：阿里。
    var captchaChannel = 0
    /// 俱乐部名称和图标，供登录页展示。
    var projectName = ""
    var projectLogo = ""
    /// 注册时是否必须填写邀请码。
    var isMustInviteCode = ""

    init() {}
    init?(map: Map) {}

    mutating func mapping(map: Map) {
        loginMethod <- map["loginMethod"]
        registerMethod <- map["registerMethod"]
        tenantCode <- map["tenantCode"]
        // 服务端可能把验证码渠道作为数字或数字字符串返回，缓存时统一写成数字。
        captchaChannel <- (map["captchaChannel"], TransformOf<Int, Any>(
            fromJSON: { value in
                if let number = value as? Int { return number }
                if let text = value as? String { return Int(text) }
                return nil
            },
            toJSON: { value in value.map { $0 as Any } }
        ))
        projectName <- map["projectName"]
        projectLogo <- map["projectLogo"]
        isMustInviteCode <- map["isMustInviteCode"]
    }

    /// 缺少租户或登录方式时，不把响应当成可供登录的系统配置。
    var isValidForLogin: Bool {
        !tenantCode.isEmpty && !loginMethod.isEmpty && (1...4).contains(captchaChannel)
    }
}

/// 老项目业务响应的外层业务码；成功码为 10000，不同于 DNS 的 Code=1。
nonisolated struct BusinessResponseStatus: Mappable {
    var code = 0
    var message = ""

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        code <- map["code"]
        message <- map["message"]
    }
}

/// 缓存封装同时记录邀请码和 Host，防止导航节点切换后误用旧配置。
nonisolated struct SystemConfigCacheRecord: Mappable {
    var schemaVersion = 1
    var appID = ""
    var apiHost = ""
    var fetchedAt: TimeInterval = 0
    var configuration = SystemConfigRecord()

    init(appID: String, apiHost: URL, configuration: SystemConfigRecord) {
        self.appID = appID
        self.apiHost = apiHost.absoluteString
        self.fetchedAt = Date().timeIntervalSince1970
        self.configuration = configuration
    }

    init?(map: Map) {
        guard map.JSON["schemaVersion"] as? Int == 1 else { return nil }
    }

    mutating func mapping(map: Map) {
        schemaVersion <- map["schemaVersion"]
        appID <- map["appID"]
        apiHost <- map["apiHost"]
        fetchedAt <- map["fetchedAt"]
        configuration <- map["configuration"]
    }
}
