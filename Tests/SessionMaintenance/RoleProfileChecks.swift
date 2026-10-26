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
        print("Role/Profile: \(count) checks passed")
    }
}
