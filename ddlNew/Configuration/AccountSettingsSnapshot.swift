import Foundation

/// 已认证账号的有效配置。读取缺失项时使用本地默认，明确坏值不开放功能。
nonisolated struct AccountSettingsSnapshot: Equatable, Sendable {
    struct Media: Equatable, Sendable {
        let provider: String
        let bucket: String
        let endpoint: String
        let region: String
        let uploadDomain: String
        let downloadDomain: String
    }
    let groupMessageIntervalMilliseconds: Int
    let messageRecallMinutes: Double
    let managersCanRecallOthers: Bool
    let onlyAdminsViewGroupPersonCount: Bool
    let callsEnabled: Bool
    let callProvider: Int?
    let zegoAppID: UInt32
    let memberActivePointsInterval: TimeInterval
    let media: Media?

    init(settings: UserSettings?) {
        func has(_ key: String) -> Bool { settings?.providedKeys.contains(key) == true }
        func flag(_ raw: String?, key: String, fallback: Bool, invalid: Bool) -> Bool {
            guard has(key) else { return fallback }
            switch raw?.lowercased() { case "1", "true": return true; case "0", "false": return false; default: return invalid }
        }
        let interval = Int(settings?.groupMessageInterval ?? "") ?? -1
        groupMessageIntervalMilliseconds = has("groupMessageInterval") && interval >= 0 ? (interval == 0 ? 2000 : interval) : LocalMessagingSettings.groupMessageIntervalMilliseconds
        let recall = Double(settings?.messageRecallTime ?? "") ?? -1
        messageRecallMinutes = !has("messageRecallTime") ? LocalMessagingSettings.messageRecallMinutes : (recall.isFinite && recall >= 0 && recall <= Double(Int.max / 60) ? recall : 0)
        managersCanRecallOthers = flag(settings?.groupMangerMessageRecallTime, key: "groupMangerMessageRecallTime", fallback: LocalMessagingSettings.managersCanRecallOthers, invalid: false)
        onlyAdminsViewGroupPersonCount = flag(settings?.onlyAllowAdminViewGroupPersonCount, key: "onlyAllowAdminViewGroupPersonCount", fallback: LocalMessagingSettings.onlyAdminsViewGroupPersonCount, invalid: true)
        let provider = has("video_source_config") ? Int(settings?.videoSourceConfig ?? "") : LocalMessagingSettings.callProvider
        callProvider = provider.flatMap { [0, 1].contains($0) ? $0 : nil }
        zegoAppID = has("video_source_config_zg_appId") ? UInt32(settings?.videoSourceConfigZgAppID ?? "") ?? 0 : (has("video_source_config") && provider == 1 ? 0 : LocalMessagingSettings.zegoAppID)
        callsEnabled = flag(settings?.enableAudioAndVideoCalls, key: "enableAudioAndVideoCalls", fallback: LocalMessagingSettings.audioVideoCallsEnabled, invalid: false) && callProvider != nil && (callProvider != 1 || zegoAppID > 0)
        let points = Double(settings?.memberActivePointsInterval ?? "") ?? -1
        memberActivePointsInterval = points.isFinite && points >= 0 ? points : 3600
        if let settings, !settings.providedKeys.isDisjoint(with: UserSettings.storageKeys) {
            let type = settings.ossConfigType
            let obs = type == "4"
            let bucket = obs ? settings.ossObsBucketName : settings.ossConfigBucketName
            let endpoint = obs ? settings.ossObsEndPoint : settings.ossConfigEndPoint
            let region = settings.ossConfigRegionID
            let put = obs ? settings.ossObsCustomDomainPut : ""
            let get = obs ? settings.ossObsCustomDomainGet : ""
            let valid = ["0", "1", "2", "3", "4"].contains(type) && (type == "0" || (!bucket.isEmpty && Self.validEndpoint(endpoint) && (!["2", "3"].contains(type) || !region.isEmpty) && (put.isEmpty || Self.validEndpoint(put)) && (get.isEmpty || Self.validEndpoint(get))))
            media = valid ? Media(provider: type, bucket: bucket, endpoint: endpoint, region: region, uploadDomain: put, downloadDomain: get) : nil
        } else {
            let obs = LocalMediaSettings.ossConfigType == "4"
            media = Media(provider: LocalMediaSettings.ossConfigType,
                bucket: obs ? LocalMediaSettings.ossOBSBucketName : LocalMediaSettings.ossConfigBucketName,
                endpoint: obs ? LocalMediaSettings.ossOBSEndPoint : LocalMediaSettings.ossConfigEndPoint,
                region: LocalMediaSettings.ossConfigRegionID,
                uploadDomain: obs ? LocalMediaSettings.ossOBSUploadDomain : "",
                downloadDomain: obs ? LocalMediaSettings.ossOBSDownloadDomain : "")
        }
    }

    private static func validEndpoint(_ text: String) -> Bool {
        guard let url = URLComponents(string: text.contains("://") ? text : "https://" + text),
              let host = url.host, !host.isEmpty, ["http", "https"].contains(url.scheme),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return false }
        return true
    }
}
