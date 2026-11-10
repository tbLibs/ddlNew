import Foundation
import ObjectMapper

@main struct SettingsChecks {
    @MainActor static func main() {
        var count = 0
        func check(_ value: Bool, _ label: String) { precondition(value, label); count += 1 }
        func settings(_ fields: [String: Any]) -> UserSettings { Mapper<UserSettings>().map(JSON: fields)! }
        let defaults = AccountSettingsSnapshot(settings: nil)
        check(defaults.messageRecallMinutes == LocalMessagingSettings.messageRecallMinutes, "defaults before configuration")
        let off = AccountSettingsSnapshot(settings: settings(["messageRecallTime": "0", "groupMessageInterval": "0", "enableAudioAndVideoCalls": false, "groupMangerMessageRecallTime": "1", "onlyAllowAdminViewGroupPersonCount": "0"]))
        check(off.messageRecallMinutes == 0 && off.groupMessageIntervalMilliseconds == 2000 && !off.callsEnabled && off.managersCanRecallOthers && !off.onlyAdminsViewGroupPersonCount, "xgd zero and switch meanings")
        let bad = AccountSettingsSnapshot(settings: settings(["messageRecallTime": "nan", "groupMessageInterval": "-1", "video_source_config": "7", "member_active_points_interval": "-1"]))
        check(bad.messageRecallMinutes == 0 && bad.groupMessageIntervalMilliseconds == 1000 && !bad.callsEnabled && bad.memberActivePointsInterval == 3600, "invalid values do not disable throttling or enable unknown calls")
        let cloud = settings(["oss_config_type": "4", "oss_obs_bucket_name": "fixture", "oss_obs_end_point": "https://obs.example.com", "oss_obs_custom_domain_put": "", "oss_obs_custom_domain_get": "https://cdn.example.com"])
        let media = AccountSettingsSnapshot(settings: cloud).media
        check(media?.provider == "4" && media?.bucket == "fixture" && media?.uploadDomain == "", "OBS own fields and empty custom domain")
        check(AccountSettingsSnapshot(settings: settings(["oss_config_type": "4"])).media == nil, "provider alone cannot use local foreign bucket")
        let cloudUser = Mapper<UserInfo>().map(JSON: ["userUID": "u", "userSettings": cloud.toJSON()])!
        let changedProvider = cloudUser.applyingProfile(["userSettings": ["oss_config_type": "2"]], expectedUID: "u")!
        check(changedProvider.userSettings?.ossObsBucketName == "" && AccountSettingsSnapshot(settings: changedProvider.userSettings).media == nil, "merged profile provider switch removes old routing")
        let sparse = cloudUser.applyingProfile(["userSettings": ["oss_obs_custom_domain_get": ""]], expectedUID: "u")!
        check(AccountSettingsSnapshot(settings: sparse.userSettings).media?.downloadDomain == "" && sparse.userSettings?.ossObsBucketName == "fixture", "same provider partial clearing keeps bucket")
        let user = Mapper<UserInfo>().map(JSON: ["userUID": "u", "userSettings": ["enableAudioAndVideoCalls": "0"]])!
        let oldCache = user.toJSONString()!
        check(UserProfileCache.decode(oldCache)?.userSettings == nil, "legacy cache cannot activate ambiguous empty settings")
        let cache = UserProfileCache.encode(user)!
        check(UserProfileCache.decode(cache)?.userSettings?.providedKeys == ["enableAudioAndVideoCalls"], "new cache preserves field presence")
        let store = AccountSettingsStore()
        let run = UUID()
        store.activate(userUID: "u", tenantID: "t", sessionID: run, settings: cloud)
        check(store.current.media?.provider == "4", "authenticated settings activate")
        store.update(settings: settings(["oss_config_type": "2"]), userUID: "u", tenantID: "t", sessionID: run)
        check(store.current.media == nil, "provider switch cannot retain old route")
        store.update(settings: cloud, userUID: "u", tenantID: "other", sessionID: run)
        check(store.current.media == nil, "wrong tenant ignored")
        let newRun = UUID()
        store.activate(userUID: "u", tenantID: "t", sessionID: newRun, settings: nil)
        store.update(settings: cloud, userUID: "u", tenantID: "t", sessionID: run)
        check(store.current == defaults, "same UID new authentication rejects old updates")
        store.reset()
        store.update(settings: cloud, userUID: "u", tenantID: "t", sessionID: newRun)
        check(store.current == defaults, "late updates after logout ignored")
        print("Account settings: \(count) checks passed")
    }
}
