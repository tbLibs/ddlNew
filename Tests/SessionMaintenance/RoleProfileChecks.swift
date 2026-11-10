import Foundation
import ObjectMapper

@main struct RoleProfileChecks {
    /// 验证权限、聊天策略与资料合并的真实映射和缓存边界。
    static func main() {
        var count = 0
        /// 失败立即终止并保留具体约束名称。
        func check(_ value: Bool, _ name: String) { precondition(value, name); count += 1 }
        let empty = Mapper<UserRoleAuthority>().map(JSON: [:])!
        check(!empty.allows("upFile"), "未下发文件上传默认关闭")
        check(empty.allows("upImageVideoFile"), "未下发图片视频上传默认开启")
        check(empty.allows("translation_switch"), "未下发翻译默认开启")
        check(!empty.allows("group_msg_pinning"), "未下发群置顶默认关闭")
        check(!empty.allows("unknown"), "未知权限不可开放")
        let malformed = Mapper<UserRoleAuthority>().map(JSON: ["upImageVideoFile": [:], "translation_switch": ["configValue": []]])!
        check(!malformed.allows("upImageVideoFile"), "条目存在但值缺失不能允许上传")
        check(!malformed.allows("translation_switch"), "非法值不能解释为默认开启")
        let values = Mapper<UserRoleAuthority>().map(JSON: [
            "upFile": ["configValue": true, "authorityKey": "upload", "configData": "1024"],
            "upImageVideoFile": ["configValue": "false"],
            "translation_switch": ["configValue": ""],
            "user_dialog_msg_pinning": ["configValue": 1],
            "edited_message_sent": ["configValue": "0"]])!
        check(values.allows("upFile"), "布尔权限兼容")
        check(!values.allows("upImageVideoFile"), "显式禁用不得被默认覆盖")
        check(values.allows("translation_switch"), "翻译空值默认开启")
        check(values.allows("user_dialog_msg_pinning"), "数字权限兼容")
        check(!values.allows("edited_message_sent"), "编辑零值关闭")
        check(values.configurationData["upFile"] == "1024", "保留服务端权限限制数据")
        let restored = Mapper<UserRoleAuthority>().map(JSONString: values.toJSONString()!)!
        check(restored.allows("upFile") && restored.configurationData["upFile"] == "1024", "权限缓存往返保留限制数据")
        let timed = Mapper<UserRoleAuthority>().map(JSON: ["edited_message_sent": ["configValue": "15"]])!
        check(timed.positiveMinutes("edited_message_sent") == 15, "编辑分钟限制不能当作布尔开关")
        check(empty.positiveMinutes("edited_message_sent") == 0, "缺少编辑权限默认关闭")
        let old = Mapper<UserInfo>().map(JSON: ["userUID":"u1", "nickname":"old", "avatar":"old-avatar", "roleId":3, "hasSecurityCode":true])!
        let updated = old.applyingProfile(["nickname":"new"], expectedUID:"u1")!
        check(updated.nickname == "new" && updated.avatar == "old-avatar", "部分资料合并不删除头像")
        check(updated.roleId == 3 && updated.hasSecurityCode, "部分资料保留角色与安全码状态")
        check(old.applyingProfile(["userUID":"other"], expectedUID:"u1") == nil, "另一用户资料不得覆盖当前用户")
        check(old.applyingProfile(["nickname":"new"], expectedUID:"other") == nil, "迟到资料不得写入另一会话")
        check(old.applyingProfile(["avatar":""], expectedUID:"u1")!.avatar.isEmpty, "明确清空字段可生效")
        let settingsPayload: [String: Any] = ["oss_config_bucket_name": "fixture-bucket", "showUserRead": "false", "groupMessageInterval": "1000"]
        let withSettings = Mapper<UserInfo>().map(JSON: ["userUID": "u1", "userSettings": settingsPayload])!
        check(Set(withSettings.userSettings!.toJSON().keys) == Set(settingsPayload.keys), "omitted settings stay omitted through cache serialization")
        check((withSettings.toJSON()["userSettings"] as? [String: Any])?["oss_config_bucket_name"] as? String == "fixture-bucket", "userSettings survives mapping and serialization")
        // 仅使用合成配置，禁止将真实用户返回、AppSign 或地址写入测试夹具。
        let allKeys = [
            "oss_config_end_point",
            "oss_obs_bucket_name",
            "oss_config_type",
            "verifyAppVersion",
            "groupMessageInterval",
            "member_active_points_interval",
            "groupMangerMessageRecallTime",
            "sys_uploadlog_domain",
            "video_source_config_zg_appSign",
            "video_source_config_zg_server_address",
            "oss_obs_end_point",
            "showUserRead",
            "enableAudioAndVideoCalls",
            "video_source_config_zg_websocket_server_address_backup",
            "oss_obs_custom_domain_get",
            "oss_config_region_id",
            "video_source_config",
            "messageRecallTime",
            "video_source_config_zg_appId",
            "isEncrypt",
            "oss_config_bucket_name",
            "onlyAllowAdminViewGroupPersonCount",
            "oss_obs_custom_domain_put",

        ]
        let fixture = Dictionary(uniqueKeysWithValues: allKeys.enumerated().map { ($0.element, "fixture-\($0.offset)") })
        let full = Mapper<UserInfo>().map(JSON: ["userUid": "u1", "userSettings": fixture])!
        check(full.userUID == "u1", "userInfo lowercase UID maps correctly")
        let serialized = full.toJSON()["userSettings"] as! [String: String]
        check(serialized == fixture, "all 23 retained fields serialize without dropping or renaming keys")
        let restoredProfile = Mapper<UserInfo>().map(JSONString: full.toJSONString()!)!
        check(restoredProfile.userSettings?.toJSON() as? [String: String] == fixture, "all settings survive persisted JSON round trip")
        check(restoredProfile.userSettings?.ossConfigBucketName == fixture["oss_config_bucket_name"], "settings accessible through typed properties")
        let partial = full.applyingProfile(["userUid": "u1", "userSettings": ["showUserRead": "true", "oss_obs_custom_domain_put": ""]], expectedUID: "u1")!
        check(partial.userSettings?.showUserRead == "true" && partial.userSettings?.ossObsCustomDomainPut == "", "partial update changes switch and allows explicit empty string")
        check(partial.userSettings?.ossConfigBucketName == full.userSettings?.ossConfigBucketName, "partial settings preserve omitted fields")
        check(full.applyingProfile(["nickname": "updated"], expectedUID: "u1")!.userSettings?.ossConfigBucketName == full.userSettings?.ossConfigBucketName, "profile-only update retains settings")
        check(full.applyingProfile(["userSettings": NSNull()], expectedUID: "u1")!.userSettings?.ossConfigBucketName == full.userSettings?.ossConfigBucketName, "null settings retain previous snapshot")
        check(full.applyingProfile(["userSettings": ["oss_config_bucket_name": NSNull()]], expectedUID: "u1")!.userSettings?.ossConfigBucketName == full.userSettings?.ossConfigBucketName, "null settings field retains previous value")
        check(full.applyingProfile(["userUid": "other", "userSettings": fixture], expectedUID: "u1") == nil, "lowercase UID mismatch rejects settings")
        check(full.applyingProfile(["userUID": "u1", "userUid": "other"], expectedUID: "u1") == nil, "conflicting UID aliases rejected")
        check(Mapper<UserInfo>().map(JSON: ["userUID": "u1"])!.userSettings == nil, "old cache without settings remains valid")
        let scalars = Mapper<UserSettings>().map(JSON: ["verifyAppVersion": true, "isEncrypt": false, "groupMessageInterval": 3000, "oss_config_type": "1"])!
        check(scalars.verifyAppVersion == "true" && scalars.isEncrypt == "false" && scalars.groupMessageInterval == "3000" && scalars.ossConfigType == "1", "native bool and numbers normalize without changing string enum values")
        let login = Mapper<AccountLoginResponse>().map(JSON: ["userUID": "u1", "token": "fixture-token", "userSettings": fixture])!
        check(login.isValid && login.userInfo?.userSettings?.toJSON() as? [String: String] == fixture, "login response exposes all settings through userInfo")
        print("Role/Profile: \(count) checks passed")
    }
}
