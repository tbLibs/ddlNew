import Foundation
import CoreFoundation
import ObjectMapper

/// 用户接口携带的配置快照。服务端使用字符串表示开关、枚举和数字，保留原值供业务按需解释。
/// 这里只解析与缓存，不自动替换本地协议参数或触发 SDK 配置；systemSecurity 保留 JSON 字符串。
nonisolated struct UserSettings: Mappable, Sendable {
    private(set) var ossConfigEndPoint = ""
    private(set) var registerSwitchAccount = ""
    private(set) var ossConfigType = ""
    private(set) var maxRegisterEquipment = ""
    private(set) var tenantCode = ""
    private(set) var isMustInviteCode = ""
    private(set) var verifyAppVersion = ""
    private(set) var groupMessageInterval = ""
    private(set) var memberActivePointsInterval = ""
    private(set) var downloadPageHtml = ""
    private(set) var registerInviteCode = ""
    private(set) var groupMembersCount = ""
    private(set) var projectName = ""
    private(set) var smsPlatformType = ""
    private(set) var captchaChannel = ""
    private(set) var tokenExpireTime = ""
    private(set) var groupMangerMessageRecallTime = ""
    private(set) var checkEnglishSymbol = ""
    private(set) var maxRegisterIP = ""
    private(set) var sysUploadlogDomain = ""
    private(set) var videoSourceConfigZgAppSign = ""
    private(set) var videoSourceConfigZgServerAddress = ""
    private(set) var allowAddFriends = ""
    private(set) var cnSmsSendCode = ""
    private(set) var maxGroupCount = ""
    private(set) var defaultFriendAddType = ""
    private(set) var captchaVersion = ""
    private(set) var ossObsEndPoint = ""
    private(set) var showUserRead = ""
    private(set) var enableAudioAndVideoCalls = ""
    private(set) var defaultAddFriendWelcome = ""
    private(set) var contactsCount = ""
    private(set) var isSignature = ""
    private(set) var videoSourceConfigZgWebsocketServerAddressBackup = ""
    private(set) var ossObsCustomDomainGet = ""
    private(set) var ossConfigRegionID = ""
    private(set) var systemSecurity = ""
    private(set) var profilesActive = ""
    private(set) var specialtyUsers = ""
    private(set) var videoSourceConfig = ""
    private(set) var projectLogo = ""
    private(set) var androidKeepaliveURL = ""
    private(set) var messageRecallTime = ""
    private(set) var videoSourceConfigZgAppID = ""
    private(set) var isEncrypt = ""
    private(set) var defaultCreateGroup = ""
    private(set) var autoCreateTeamGroup = ""
    private(set) var numberAccount = ""
    private(set) var defaultInviteRegisterHtml = ""
    private(set) var defaultFriendIds = ""
    private(set) var ossConfigBucketName = ""
    private(set) var onlyAllowAdminViewGroupPersonCount = ""
    private(set) var ossObsCustomDomainPut = ""
    private(set) var registerMethod = ""
    private(set) var loginMethod = ""
    private(set) var allowBeCreateGroup = ""

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        ossConfigEndPoint <- (map["oss_config_end_point"], Self.stringValue)
        registerSwitchAccount <- (map["registerSwitchAccount"], Self.stringValue)
        ossConfigType <- (map["oss_config_type"], Self.stringValue)
        maxRegisterEquipment <- (map["maxRegisterEquipment"], Self.stringValue)
        tenantCode <- (map["tenantCode"], Self.stringValue)
        isMustInviteCode <- (map["isMustInviteCode"], Self.stringValue)
        verifyAppVersion <- (map["verifyAppVersion"], Self.stringValue)
        groupMessageInterval <- (map["groupMessageInterval"], Self.stringValue)
        memberActivePointsInterval <- (map["member_active_points_interval"], Self.stringValue)
        downloadPageHtml <- (map["downloadPageHtml"], Self.stringValue)
        registerInviteCode <- (map["registerInviteCode"], Self.stringValue)
        groupMembersCount <- (map["groupMembersCount"], Self.stringValue)
        projectName <- (map["projectName"], Self.stringValue)
        smsPlatformType <- (map["smsPlatformType"], Self.stringValue)
        captchaChannel <- (map["captchaChannel"], Self.stringValue)
        tokenExpireTime <- (map["tokenExpireTime"], Self.stringValue)
        groupMangerMessageRecallTime <- (map["groupMangerMessageRecallTime"], Self.stringValue)
        checkEnglishSymbol <- (map["checkEnglishSymbol"], Self.stringValue)
        maxRegisterIP <- (map["maxRegisterIP"], Self.stringValue)
        sysUploadlogDomain <- (map["sys_uploadlog_domain"], Self.stringValue)
        videoSourceConfigZgAppSign <- (map["video_source_config_zg_appSign"], Self.stringValue)
        videoSourceConfigZgServerAddress <- (map["video_source_config_zg_server_address"], Self.stringValue)
        allowAddFriends <- (map["allowAddFriends"], Self.stringValue)
        cnSmsSendCode <- (map["cnSmsSendCode"], Self.stringValue)
        maxGroupCount <- (map["maxGroupCount"], Self.stringValue)
        defaultFriendAddType <- (map["defaultFriendAddType"], Self.stringValue)
        captchaVersion <- (map["captchaVersion"], Self.stringValue)
        ossObsEndPoint <- (map["oss_obs_end_point"], Self.stringValue)
        showUserRead <- (map["showUserRead"], Self.stringValue)
        enableAudioAndVideoCalls <- (map["enableAudioAndVideoCalls"], Self.stringValue)
        defaultAddFriendWelcome <- (map["defaultAddFriendWelcome"], Self.stringValue)
        contactsCount <- (map["contactsCount"], Self.stringValue)
        isSignature <- (map["isSignature"], Self.stringValue)
        videoSourceConfigZgWebsocketServerAddressBackup <- (map["video_source_config_zg_websocket_server_address_backup"], Self.stringValue)
        ossObsCustomDomainGet <- (map["oss_obs_custom_domain_get"], Self.stringValue)
        ossConfigRegionID <- (map["oss_config_region_id"], Self.stringValue)
        systemSecurity <- (map["systemSecurity"], Self.stringValue)
        profilesActive <- (map["profilesActive"], Self.stringValue)
        specialtyUsers <- (map["specialtyUsers"], Self.stringValue)
        videoSourceConfig <- (map["video_source_config"], Self.stringValue)
        projectLogo <- (map["projectLogo"], Self.stringValue)
        androidKeepaliveURL <- (map["android_kepplive_url"], Self.stringValue)
        messageRecallTime <- (map["messageRecallTime"], Self.stringValue)
        videoSourceConfigZgAppID <- (map["video_source_config_zg_appId"], Self.stringValue)
        isEncrypt <- (map["isEncrypt"], Self.stringValue)
        defaultCreateGroup <- (map["defaultCreateGroup"], Self.stringValue)
        autoCreateTeamGroup <- (map["autoCreateTeamGroup"], Self.stringValue)
        numberAccount <- (map["numberAccount"], Self.stringValue)
        defaultInviteRegisterHtml <- (map["defaultInviteRegisterHtml"], Self.stringValue)
        defaultFriendIds <- (map["defaultFriendIds"], Self.stringValue)
        ossConfigBucketName <- (map["oss_config_bucket_name"], Self.stringValue)
        onlyAllowAdminViewGroupPersonCount <- (map["onlyAllowAdminViewGroupPersonCount"], Self.stringValue)
        ossObsCustomDomainPut <- (map["oss_obs_custom_domain_put"], Self.stringValue)
        registerMethod <- (map["registerMethod"], Self.stringValue)
        loginMethod <- (map["loginMethod"], Self.stringValue)
        allowBeCreateGroup <- (map["allowBeCreateGroup"], Self.stringValue)
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
