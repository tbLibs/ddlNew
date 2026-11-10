import Foundation
import CoreFoundation
import ObjectMapper

/// 用户接口携带的配置快照。服务端使用字符串表示开关、枚举和数字，保留原值供业务按需解释。
/// 这里只解析与缓存，不自动替换本地协议参数或触发 SDK 配置。
nonisolated struct UserSettings: Mappable, Sendable {
    /// 对象存储服务节点，对应 oss_config_end_point；xgd 用于构造上传和资源访问地址。
    private(set) var ossConfigEndPoint = ""
    /// 文件存储供应商：0 MinIO、1 阿里云、2 AWS、3 腾讯云、4 华为云。
    private(set) var ossConfigType = ""
    /// 是否检查 App 版本；xgd 为 false 时不请求 getLatestVersion，声明默认 true。
    private(set) var verifyAppVersion = ""
    /// 群消息最小发送间隔，单位毫秒；xgd 在值为 0 时按 2000 毫秒处理。
    private(set) var groupMessageInterval = ""
    /// 群成员活跃积分查询间隔，单位秒，对应 member_active_points_interval。
    private(set) var memberActivePointsInterval = ""
    /// 群主／管理员撤回他人群消息的开关：0 关闭、1 开启；历史字段名虽含 Time，实际不是时长。
    private(set) var groupMangerMessageRecallTime = ""
    /// 日志上报域名，对应 sys_uploadlog_domain；xgd 用于构造日志上传地址。
    private(set) var sysUploadlogDomain = ""
    /// 即构 AppSign 鉴权参数，对应 video_source_config_zg_appSign；不应写入日志。
    private(set) var videoSourceConfigZgAppSign = ""
    /// 即构服务器 WebSocket 主地址；xgd 传给通话 SDK 配置。
    private(set) var videoSourceConfigZgServerAddress = ""
    /// 华为云 OBS 默认服务节点，对应 oss_obs_end_point。
    private(set) var ossObsEndPoint = ""
    /// 华为云 OBS 存储桶名称，对应 oss_obs_bucket_name。
    private(set) var ossObsBucketName = ""
    /// 消息已读状态显示配置；xgd 当前实际读取角色权限 showUserRead，未直接使用此系统字段。
    private(set) var showUserRead = ""
    /// 音视频通话总开关：1 开启、0 关闭；xgd 配置刷新也兼容字符串 true。
    private(set) var enableAudioAndVideoCalls = ""
    /// 即构服务器 WebSocket 备用地址；xgd 传给通话 SDK 配置。
    private(set) var videoSourceConfigZgWebsocketServerAddressBackup = ""
    /// 华为云 OBS 自定义下载域名，对应 oss_obs_custom_domain_get。
    private(set) var ossObsCustomDomainGet = ""
    /// 对象存储区域标识，对应 oss_config_region_id；用于供应商区域及请求签名。
    private(set) var ossConfigRegionID = ""
    /// 音视频供应商：0 LiveKit、1 即构（Zego）。
    private(set) var videoSourceConfig = ""
    /// 普通消息允许撤回的时间窗口，单位分钟；0 关闭，正数为发送后可撤回的时长。
    private(set) var messageRecallTime = ""
    /// 即构 App ID，对应 video_source_config_zg_appId；使用时需校验为有效 UInt32。
    private(set) var videoSourceConfigZgAppID = ""
    /// 加密相关服务端配置；xgd 未见消费此系统字段，不能据此改变现有消息或网络加密协议。
    private(set) var isEncrypt = ""
    /// 对象存储桶名称，对应 oss_config_bucket_name；华为 OBS 使用独立的 ossObsBucketName。
    private(set) var ossConfigBucketName = ""
    /// 是否仅允许群管理查看群人数：1 是、0 否；xgd 同时考虑群角色和角色权限的放行条件。
    private(set) var onlyAllowAdminViewGroupPersonCount = ""
    /// 华为云 OBS 自定义上传域名，对应 oss_obs_custom_domain_put。
    private(set) var ossObsCustomDomainPut = ""

    /// 仅记录接口实际提供的键，缺失与显式空字符串具有不同含义。
    private(set) var providedKeys: Set<String> = []

    init?(map: Map) {
        providedKeys = Set(map.JSON.filter { Self.stringValue.transformFromJSON($0.value) != nil }.keys)
    }

    mutating func mapping(map: Map) {
        if map.mappingType == .fromJSON || providedKeys.contains("oss_config_end_point") { ossConfigEndPoint <- (map["oss_config_end_point"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("oss_config_type") { ossConfigType <- (map["oss_config_type"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("verifyAppVersion") { verifyAppVersion <- (map["verifyAppVersion"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("groupMessageInterval") { groupMessageInterval <- (map["groupMessageInterval"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("member_active_points_interval") { memberActivePointsInterval <- (map["member_active_points_interval"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("groupMangerMessageRecallTime") { groupMangerMessageRecallTime <- (map["groupMangerMessageRecallTime"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("sys_uploadlog_domain") { sysUploadlogDomain <- (map["sys_uploadlog_domain"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("video_source_config_zg_appSign") { videoSourceConfigZgAppSign <- (map["video_source_config_zg_appSign"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("video_source_config_zg_server_address") { videoSourceConfigZgServerAddress <- (map["video_source_config_zg_server_address"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("oss_obs_end_point") { ossObsEndPoint <- (map["oss_obs_end_point"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("oss_obs_bucket_name") { ossObsBucketName <- (map["oss_obs_bucket_name"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("showUserRead") { showUserRead <- (map["showUserRead"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("enableAudioAndVideoCalls") { enableAudioAndVideoCalls <- (map["enableAudioAndVideoCalls"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("video_source_config_zg_websocket_server_address_backup") { videoSourceConfigZgWebsocketServerAddressBackup <- (map["video_source_config_zg_websocket_server_address_backup"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("oss_obs_custom_domain_get") { ossObsCustomDomainGet <- (map["oss_obs_custom_domain_get"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("oss_config_region_id") { ossConfigRegionID <- (map["oss_config_region_id"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("video_source_config") { videoSourceConfig <- (map["video_source_config"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("messageRecallTime") { messageRecallTime <- (map["messageRecallTime"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("video_source_config_zg_appId") { videoSourceConfigZgAppID <- (map["video_source_config_zg_appId"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("isEncrypt") { isEncrypt <- (map["isEncrypt"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("oss_config_bucket_name") { ossConfigBucketName <- (map["oss_config_bucket_name"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("onlyAllowAdminViewGroupPersonCount") { onlyAllowAdminViewGroupPersonCount <- (map["onlyAllowAdminViewGroupPersonCount"], Self.stringValue) }
        if map.mappingType == .fromJSON || providedKeys.contains("oss_obs_custom_domain_put") { ossObsCustomDomainPut <- (map["oss_obs_custom_domain_put"], Self.stringValue) }
    }

    static let storageKeys: Set<String> = ["oss_config_type", "oss_config_bucket_name", "oss_config_end_point", "oss_config_region_id", "oss_obs_bucket_name", "oss_obs_end_point", "oss_obs_custom_domain_put", "oss_obs_custom_domain_get"]

    func merging(_ fields: [String: Any]) -> [String: Any] {
        let incoming = fields.filter { !($0.value is NSNull) }
        var previous = toJSON()
        if let next = Self.stringValue.transformFromJSON(incoming["oss_config_type"]),
           next != ossConfigType {
            previous = previous.filter { !Self.storageKeys.contains($0.key) }
        }
        return previous.merging(incoming) { _, new in new }
    }

    /// 兼容服务端直接返回数字或布尔值，字符串的 true/false、0/1 和空值保持原样。
    private static var stringValue: TransformOf<String, Any> {
        TransformOf(fromJSON: { value in
            if let text = value as? String { return text }
            if let number = value as? NSNumber {
                if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue ? "true" : "false" }
                return number.stringValue
            }
            return nil
        }, toJSON: { $0 })
    }
}
