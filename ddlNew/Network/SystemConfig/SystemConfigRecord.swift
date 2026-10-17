//
//  SystemConfigRecord.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation
import ObjectMapper

/// 老项目 NoaSystemSettingModel 的登录及聊天策略；不缓存音视频等服务端密钥。
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
    /// 是否要求注册密码包含英文符号。
    var checkEnglishSymbol = false
    /// 群消息最小发送间隔，单位毫秒；零值由聊天策略沿用旧端 2000 毫秒。
    var groupMessageInterval: Int64 = 0
    /// 本人消息允许撤回的分钟数，非正数关闭撤回。
    var messageRecallTime = "0"
    /// 是否允许群管理撤回他人消息，0 关闭，1 开启。
    var groupMangerMessageRecallTime = "0"
    /// 仅管理员可查看群人数，缺失时沿用旧端开启默认。
    var onlyAllowAdminViewGroupPersonCount = "1"
    /// 存储类型：0 Minio、1 阿里云、2 AWS、3 腾讯云、4 华为云；未下发不假定供应商。
    var ossConfigType = ""
    var ossConfigBucketName = ""
    var ossConfigEndPoint = ""
    var ossConfigRegionID = ""
    var ossOBSBucketName = ""
    var ossOBSEndPoint = ""
    var ossOBSUploadDomain = ""
    var ossOBSDownloadDomain = ""

    /// 提供安全的缺省策略供首次配置尚未返回的页面读取。
    init() {}
    /// ObjectMapper 使用同一映射入口解析网络及缓存。
    init?(map: Map) {}

    /// 兼容服务端数字和数字字符串，同时保持字段原始语义。
    mutating func mapping(map: Map) {
        let stringValue = TransformOf<String, Any>(
            fromJSON: { value in
                if let text = value as? String { return text }
                if let number = value as? NSNumber { return number.stringValue }
                return nil
            }, toJSON: { $0 }
        )
        loginMethod <- (map["loginMethod"], stringValue)
        registerMethod <- (map["registerMethod"], stringValue)
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
        isMustInviteCode <- (map["isMustInviteCode"], stringValue)
        messageRecallTime <- (map["messageRecallTime"], stringValue)
        groupMangerMessageRecallTime <- (map["groupMangerMessageRecallTime"], stringValue)
        onlyAllowAdminViewGroupPersonCount <- (map["onlyAllowAdminViewGroupPersonCount"], stringValue)
        ossConfigType <- (map["oss_config_type"], stringValue)
        ossConfigBucketName <- map["oss_config_bucket_name"]
        ossConfigEndPoint <- map["oss_config_end_point"]
        ossConfigRegionID <- map["oss_config_region_id"]
        ossOBSBucketName <- map["oss_obs_bucket_name"]
        ossOBSEndPoint <- map["oss_obs_end_point"]
        ossOBSUploadDomain <- map["oss_obs_custom_domain_put"]
        ossOBSDownloadDomain <- map["oss_obs_custom_domain_get"]
        groupMessageInterval <- (map["groupMessageInterval"], TransformOf<Int64, Any>(
            fromJSON: { value in
                if let number = value as? NSNumber { return max(0, number.int64Value) }
                if let text = value as? String, let number = Int64(text) { return max(0, number) }
                return nil
            }, toJSON: { $0 }))
        checkEnglishSymbol <- (map["checkEnglishSymbol"], TransformOf<Bool, Any>(
            fromJSON: { value in
                if let number = value as? NSNumber { return number.boolValue }
                if let text = value as? String { return ["1", "true", "yes"].contains(text.lowercased()) }
                return nil
            }, toJSON: { $0 }
        ))
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

    /// 业务响应必须经统一成功码检查。
    init?(map: Map) {}

    /// 解析响应状态，不把 HTTP 成功当作业务成功。
    mutating func mapping(map: Map) {
        code <- map["code"]
        message <- map["message"]
    }
}

/// 缓存封装同时记录邀请码和 Host，防止导航节点切换后误用旧配置。
nonisolated struct SystemConfigCacheRecord: Mappable {
    var schemaVersion = 1
    var lastLiceseId = ""
    var apiHost = ""
    var fetchedAt: TimeInterval = 0
    var configuration = SystemConfigRecord()

    /// 将配置与取得配置的导航上下文一起保存。
    init(lastLiceseId: String, apiHost: URL?, configuration: SystemConfigRecord) {
        self.lastLiceseId = lastLiceseId
        self.apiHost = (apiHost?.absoluteString ?? "")
        self.fetchedAt = Date().timeIntervalSince1970
        self.configuration = configuration
    }

    /// 拒绝未知缓存格式，避免旧数据误解释为有效配置。
    init?(map: Map) {
        guard map.JSON["schemaVersion"] as? Int == 1 else { return nil }
    }

    /// 序列化缓存身份、时间及完整业务策略。
    mutating func mapping(map: Map) {
        schemaVersion <- map["schemaVersion"]
        lastLiceseId <- map["lastLiceseId"]
        apiHost <- map["apiHost"]
        fetchedAt <- map["fetchedAt"]
        configuration <- map["configuration"]
    }
}
