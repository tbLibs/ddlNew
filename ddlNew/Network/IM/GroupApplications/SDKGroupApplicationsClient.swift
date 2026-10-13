// Created by taobo on 2026/10/13.
import Foundation
import ObjectMapper
import NoaChatCore
import ObjectiveC

@MainActor final class SDKGroupApplicationsClient: GroupApplicationsClient {
    /// 使用列表真实参数与固定十条分页，单群入口核验管理权限。
    func load(userUID: String, groupID: String?, pendingOnly: Bool, page: Int) async throws -> GroupApplicationsPage {
        try validate(userUID: userUID, groupID: groupID)
        let notifications = groupID == nil ? notificationSnapshot(userUID: userUID) : nil
        var values: [String: Any] = ["userUid": userUID, "pageNumber": max(1, page), "pageSize": 10]
        if pendingOnly { values["beStatus"] = 1 }
        if let groupID { values["groupId"] = groupID }
        let params = NSMutableDictionary(dictionary: values)
        let json = try await request { success, failure in
            let sdk = NoaIMSDKManager.sharedTool()
            if groupID != nil { sdk.groupManagerApplyJoinGroupList(withData: params, onSuccess: success, onFailure: failure) }
            else { sdk.groupNotificationApplyJoinGroupList(withData: params, onSuccess: success, onFailure: failure) }
        }
        try validate(userUID: userUID, groupID: groupID)
        guard let payload = Mapper<GroupApplicationsPayload>().map(JSONString: json) else { throw ChatClientError.unavailable("群申请数据无效，请刷新重试") }
        return GroupApplicationsPage(records: payload.records.map(\.record).filter { !$0.id.isEmpty && !$0.groupID.isEmpty }, total: payload.total, notifications: notifications)
    }
    /// 返回每条真实处理结果，缺少或失败的申请不能标为成功。
    func review(userUID: String, records: [GroupApplicationRecord], accept: Bool) async throws -> GroupApplicationOutcome {
        try validate(userUID: userUID, groupID: nil)
        for groupID in Set(records.map(\.groupID)) { try validate(userUID: userUID, groupID: groupID) }
        let params = NSMutableDictionary(dictionary: ["verfiyStatus": accept ? 1 : 2, "verfiyUserId": userUID,
            "memreqParams": records.map { ["groupId": $0.groupID, "memreqUuid": $0.id] }])
        let json = try await request { success, failure in
            NoaIMSDKManager.sharedTool().groupJoinGroupApplyHandle(withData: params, onSuccess: success, onFailure: failure)
        }
        try validate(userUID: userUID, groupID: nil)
        guard let data = json.data(using: .utf8), let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ChatClientError.unavailable("群审核回执无效，请刷新确认状态")
        }
        var successful: Set<String> = []
        for record in records {
            if rows.contains(where: { ($0[record.id] as? NSNumber)?.boolValue == true &&
                ($0["beStatus"] as? NSNumber)?.intValue == (accept ? 4 : 5) }) { successful.insert(record.id) }
        }
        return GroupApplicationOutcome(successfulIDs: successful, failedIDs: Set(records.map(\.id)).subtracting(successful))
    }
    /// 沿用旧群通知协议，申请UUID不能作为系统消息的已读游标。
    func markNotificationsRead(userUID: String, snapshot: GroupNotificationReadSnapshot? = nil) async throws {
        try validate(userUID: userUID, groupID: nil)
        let snapshot = snapshot ?? notificationSnapshot(userUID: userUID)
        let loginRun = snapshot.loginRun
        let license = snapshot.license
        guard snapshot.userUID == userUID, loginRun == LoginSessionService.shared.maintenanceSessionID,
              license == OSSConnectionBootstrap.shared.current?.lastLiceseId else { throw CancellationError() }
        let sdk = NoaIMSDKManager.sharedTool()
        for boundary in snapshot.messages {
            let id = boundary.sessionID, messageID = boundary.messageID, unread = boundary.unreadCount
            let waiter = SDKChatRequestWaiter<Bool>()
            let accepted = try await waiter.run {
                sdk.readedMessage(NSMutableDictionary(dictionary: ["userUid": userUID, "chatType": 5,
                    "smsgId": messageID, "sendMsgUserUid": id]), onSuccess: { _, _ in
                    Task { @MainActor in waiter.finish(.success(true)) }
                }, onFailure: { code, _, _ in
                    Task { @MainActor in waiter.finish(.failure(ChatClientError.unavailable("群通知已读上报失败（\(code)），请刷新重试"))) }
                })
            }
            try Task<Never, Never>.checkCancellation()
            objc_sync_enter(sdk)
            defer { objc_sync_exit(sdk) }
            guard accepted, loginRun == LoginSessionService.shared.maintenanceSessionID,
                  license == OSSConnectionBootstrap.shared.current?.lastLiceseId,
                  sdk.myUserID() == userUID, sdk.isUserDatabaseReady() else { throw CancellationError() }
            let cached: LingIMSessionModel? = sdk.toolCheckMySession(with: id)
            guard let current = cached else { continue }
            let newest: NoaIMChatMessageModel? = current.sessionLatestMessage ?? sdk.toolGetLatestChatMessage(withSessionID: id)
            // 网络等待期间的新通知保留未读，不能用最新快照无条件清零。
            current.sessionUnreadCount = newest?.serviceMsgID == messageID || current.sessionUnreadCount == 0
                ? 0 : max(1, current.sessionUnreadCount - unread)
            current.readTag = 0
            guard sdk.toolUpdateSession(with: current) else { throw ChatClientError.invalidResponse }
        }
    }
    /// 列表发起前固定系统会话最新消息及未读计数，成功后只清这次边界。
    private func notificationSnapshot(userUID: String) -> GroupNotificationReadSnapshot {
        let sdk = NoaIMSDKManager.sharedTool()
        objc_sync_enter(sdk)
        defer { objc_sync_exit(sdk) }
        let sessions = (sdk.toolGetMySessionListExcept("") as? [LingIMSessionModel] ?? [])
            .filter { Int($0.sessionType.rawValue) == 5 && ($0.sessionUnreadCount > 0 || $0.readTag > 0) }
        let messages = sessions.compactMap { session -> GroupNotificationReadBoundary? in
            guard let id = session.sessionID, !id.isEmpty else { return nil }
            let latest: NoaIMChatMessageModel? = session.sessionLatestMessage ?? sdk.toolGetLatestChatMessage(withSessionID: id)
            guard let messageID = latest?.serviceMsgID, !messageID.isEmpty else { return nil }
            return GroupNotificationReadBoundary(sessionID: id, messageID: messageID, unreadCount: max(0, session.sessionUnreadCount))
        }
        return GroupNotificationReadSnapshot(userUID: userUID, loginRun: LoginSessionService.shared.maintenanceSessionID,
            license: OSSConnectionBootstrap.shared.current?.lastLiceseId, messages: messages)
    }
    /// 当前账号及本地群角色二次校验，服务端仍是最终权限来源。
    private func validate(userUID: String, groupID: String?) throws {
        let sdk = NoaIMSDKManager.sharedTool()
        guard sdk.myUserID() == userUID, sdk.isUserDatabaseReady() else { throw CancellationError() }
        if let groupID {
            let cached: LingIMGroupModel? = sdk.toolCheckMyGroup(with: groupID)
            guard let group = cached, group.leaveGroupStatus == 0,
                  group.groupStatus == 1, [1, 2].contains(group.userGroupRole) else {
                throw ChatClientError.permission("当前已无群管理权限，请刷新后重试")
            }
        }
    }
    /// 将可变 SDK JSON 转成字符串快照，等待有超时和取消上限。
    private func request(_ start: (@escaping LingIMSuccessCallback, @escaping LingIMFailureCallback) -> Void) async throws -> String {
        let loginRun = LoginSessionService.shared.maintenanceSessionID
        let license = OSSConnectionBootstrap.shared.current?.lastLiceseId
        let userUID = NoaIMSDKManager.sharedTool().myUserID()
        let waiter = SDKChatRequestWaiter<String>()
        let result = try await waiter.run {
            start({ data, _ in
                let bytes = data.flatMap { try? JSONSerialization.data(withJSONObject: $0) }
                let json = bytes.flatMap { String(data: $0, encoding: .utf8) }
                Task { @MainActor in
                    if let json { waiter.finish(.success(json)) }
                    else { waiter.finish(.failure(ChatClientError.unavailable("群申请数据无效，请刷新重试"))) }
                }
            }, { code, _, _ in
                Task { @MainActor in waiter.finish(.failure(ChatClientError.unavailable("群申请请求失败（\(code)），请稍后重试"))) }
            })
        }
        try Task<Never, Never>.checkCancellation()
        guard loginRun == LoginSessionService.shared.maintenanceSessionID,
              license == OSSConnectionBootstrap.shared.current?.lastLiceseId,
              NoaIMSDKManager.sharedTool().myUserID() == userUID else { throw CancellationError() }
        return result
    }
}
