import Foundation
import ObjectMapper

/// 缓存版本只存在本地封装中，不写入 UserInfo 或业务请求。
nonisolated enum UserProfileCache {
    static func encode(_ user: UserInfo) -> String? {
        var json = user.toJSON()
        json["_settingsCacheVersion"] = 1
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ text: String) -> UserInfo? {
        guard let data = text.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        // 旧模型曾把所有省略项写成空值，不能据此决定禁用功能或存储路由。
        if json["_settingsCacheVersion"] as? Int != 1 { json.removeValue(forKey: "userSettings") }
        json.removeValue(forKey: "_settingsCacheVersion")
        return Mapper<UserInfo>().map(JSON: json)
    }
}
