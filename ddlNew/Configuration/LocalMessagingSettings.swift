import Foundation

/// 用户于2026-10-26提供的访客与登录配置一致；随应用版本发布。
nonisolated enum LocalMessagingSettings {
    static let groupMessageIntervalMilliseconds = 1000
    static let messageRecallMinutes: Double = 5
    static let managersCanRecallOthers = false
    static let onlyAdminsViewGroupPersonCount = true
    static let audioVideoCallsEnabled = true
    static let callProvider = 1
    static let zegoAppID: UInt32 = 40878197
}

/// 仅保存存储路由；上传临时凭据仍由已认证会话向服务端申请。
nonisolated enum LocalMediaSettings {
    static let ossConfigType = "1"
    static let ossConfigBucketName = "u260711-2"
    static let ossConfigEndPoint = "https://oss-accelerate.aliyuncs.com"
    static let ossConfigRegionID = "cn-hongkong"
    static let ossOBSBucketName = "lot"
    static let ossOBSEndPoint = "https://obs.cn-south-1.myhuaweicloud.com"
    static let ossOBSUploadDomain = "http://lot.sfzye.com"
    static let ossOBSDownloadDomain = "https://lots.sfzye.com"
}
