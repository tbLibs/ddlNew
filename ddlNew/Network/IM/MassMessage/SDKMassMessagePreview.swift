//
//  SDKMassMessagePreview.swift
//  ddlNew
//
//  Created by taobo on 2026/10/23.
//

import Foundation
import NoaChatCore
import MMKV
import ObjectiveC

/// 复用SDK同步已维护的群发摘要key，不建立第二份群发消息缓存。
enum SDKMassMessagePreview {
    @MainActor static func update(_ records: [MassMessageRecord], context: ChatContext) {
        guard ChatRuntime.shared.isCurrent(context) else { return }
        let sdk = NoaIMSDKManager.sharedTool()
        objc_sync_enter(sdk); defer { objc_sync_exit(sdk) }
        guard sdk.myUserID() == context.userUID, sdk.isUserDatabaseReady() else { return }
        let key = context.userUID + "-MassMessage"
        if let record = records.first {
            let json: [String: Any] = ["id": record.id, "labelId": record.labelID, "label": record.label,
                "sendTime": record.sentAt, "mtype": record.type, "status": record.status, "totalCount": record.total,
                "errorCount": record.errors, "body": MassMessageComposerStore.reusedBody(record), "userUid": context.userUID]
            if let data = try? JSONSerialization.data(withJSONObject: json), let text = String(data: data, encoding: .utf8) { MMKV.default()?.set(text, forKey: key) }
            if let session = sdk.toolCheckMySession(with: context.route.id) as LingIMSessionModel?, let date = date(record.sentAt) {
                session.sessionLatestTime = Int64(date.timeIntervalSince1970 * 1000)
                _ = sdk.toolUpdateSession(with: session)
            }
        } else { MMKV.default()?.removeValue(forKey: key) }
        Task { await LoginSessionService.shared.conversations.reload() }
    }
    /// 调用者持有SDK数据库锁并确认用户，兼容SDK已有JSON映射。
    nonisolated static func latest(userUID: String) -> MassMessageRecord? {
        guard let text = MMKV.default()?.string(forKey: userUID + "-MassMessage"), let json = MassMessagePayload.object(text) else { return nil }
        return try? MassMessagePayload.records(["records": [json]]).records.first
    }
    nonisolated static func date(_ value: String) -> Date? {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)
    }
}
