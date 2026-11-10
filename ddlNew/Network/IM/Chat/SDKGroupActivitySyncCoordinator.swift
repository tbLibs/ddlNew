import Foundation
import NoaChatCore
import ObjectiveC

/// 复用SDK成员／积分接口和成员表；不调用旧SDK会在迟到回包中直接写库的分页封装。
@MainActor final class SDKGroupActivitySyncCoordinator {
    static let shared = SDKGroupActivitySyncCoordinator()
    private let engine = GroupActivitySyncEngine()
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }

    func refreshIfNeeded(context: ChatContext) {
        guard context.route.kind == .group, valid(context),
              let group = sdk.toolCheckMyGroup(with: context.route.id) as LingIMGroupModel?,
              group.groupStatus == 1, group.leaveGroupStatus == 0 else { return }
        let now = NSDate.getCurrentServerMillisecondTime()
        let lastSync = group.lastSyncActiviteScoreime
        let key = "\(context.tenantID):\(context.userUID):\(context.sessionID):\(context.route.id)"
        engine.refresh(key: key, lastSyncMilliseconds: lastSync, nowMilliseconds: now,
            interval: AccountSettingsStore.shared.current.memberActivePointsInterval,
            valid: { [weak self] in self?.valid(context) == true }) { [weak self] current in
                guard let self else { throw CancellationError() }
                // 先取完整成员，再增量取积分，任何失败都不提前推进同步游标。
                var members: [String: [String: Any]] = [:]
                var page = 1
                while true {
                    guard current() else { throw CancellationError() }
                    let data = try await self.request(context: context, points: false, page: page, lastSync: lastSync)
                    guard current() else { throw CancellationError() }
                    let rows = try ChatGroupMemberPage.rows(from: data)
                    let pagination = try GroupActivityMemberPagination(data: data, expectedPage: page, rowCount: rows.count)
                    let previous = members.count
                    for row in rows { if let uid = row["userUid"] as? String { members[uid] = row } }
                    guard members.count - previous == rows.count else { throw ChatClientError.invalidResponse }
                    if !pagination.hasNext { break }
                    guard page < 10_000 else { throw ChatClientError.invalidResponse }
                    page += 1
                }
                var scores: [String: Int] = [:]
                page = 1
                while true {
                    guard current() else { throw CancellationError() }
                    let data = try await self.request(context: context, points: true, page: page, lastSync: lastSync)
                    guard current() else { throw CancellationError() }
                    let result = try GroupActivityScorePage(data: data, expectedPage: page)
                    scores.merge(result.scores) { _, latest in latest }
                    if !result.hasNext { break }
                    guard page < 10_000 else { throw ChatClientError.invalidResponse }
                    page += 1
                }
                try self.commit(members: members, scores: scores, cursor: now, context: context, current: current)
        }
    }

    func reset() { engine.reset() }

    private func valid(_ context: ChatContext) -> Bool {
        ChatRuntime.shared.isCurrent(context) && IMUserAuthenticationService.shared.isAuthenticated
            && AccountSettingsStore.shared.matches(userUID: context.userUID, tenantID: context.tenantID, sessionID: context.sessionID)
            && sdk.myUserID() == context.userUID && sdk.isUserDatabaseReady()
    }

    private func request(context: ChatContext, points: Bool, page: Int, lastSync: Int64) async throws -> [String: Any] {
        let waiter = SDKChatRequestWaiter<String>()
        let params = NSMutableDictionary(dictionary: ["groupId": context.route.id, "userUid": context.userUID,
            "pageNumber": page, "pageSize": 100, "pageStart": 0])
        if points { params["lastSyncTime"] = lastSync }
        let text = try await waiter.run {
            let success: LingIMSuccessCallback = { data, _ in
                let bytes = (data as? [String: Any]).flatMap { try? JSONSerialization.data(withJSONObject: $0) }
                let text = bytes.flatMap { String(data: $0, encoding: .utf8) }
                Task { @MainActor in
                    if let text { waiter.finish(.success(text)) }
                    else { waiter.finish(.failure(ChatClientError.invalidResponse)) }
                }
            }
            let failure: LingIMFailureCallback = { _, _, _ in
                Task { @MainActor in waiter.finish(.failure(ChatClientError.unavailable("群成员积分同步失败"))) }
            }
            if points { sdk.groupGetMemberActiviteScore(with: params, onSuccess: success, onFailure: failure) }
            else { sdk.getGroupMemberList(with: params, onSuccess: success, onFailure: failure) }
        }
        guard valid(context), let data = text.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw CancellationError() }
        return json
    }

    private func commit(members: [String: [String: Any]], scores: [String: Int], cursor: Int64,
                        context: ChatContext, current: () -> Bool) throws {
        objc_sync_enter(sdk)
        defer { objc_sync_exit(sdk) }
        guard current(), valid(context), let group = sdk.toolCheckMyGroup(with: context.route.id) as LingIMGroupModel?,
              group.groupStatus == 1, group.leaveGroupStatus == 0 else { throw CancellationError() }
        for (uid, row) in members {
            let model = (sdk.imSdkCheckGroupMember(with: uid, groupID: context.route.id) as LingIMGroupMemberModel?) ?? LingIMGroupMemberModel()
            model.userUid = uid
            model.memberIsInGroup = true
            model.role = Self.integer(row["role"]) ?? model.role
            model.disableStatus = Self.integer(row["disableStatus"]) ?? model.disableStatus
            model.nicknameInGroup = row["nicknameInGroup"] as? String ?? model.nicknameInGroup
            model.remarks = row["remarks"] as? String ?? model.remarks
            model.userNickname = row["userNickname"] as? String ?? row["nickname"] as? String ?? model.userNickname
            model.userAvatar = row["userAvatar"] as? String ?? row["avatar"] as? String ?? model.userAvatar
            model.showName = !(model.remarks ?? "").isEmpty ? model.remarks : !(model.nicknameInGroup ?? "").isEmpty ? model.nicknameInGroup : model.userNickname
            if let score = scores[uid] { model.activityScroe = score }
            guard sdk.imSdkInsertOrUpdateGroupMember(model, groupID: context.route.id) else { throw ChatClientError.invalidResponse }
        }
        // 全页和写库都成功才推进游标；空增量也成功，避免每次进群都重复请求。
        group.lastSyncActiviteScoreime = cursor
        guard sdk.toolInsertOrUpdateGroupModel(with: group) else { throw ChatClientError.invalidResponse }
    }
    private static func integer(_ value: Any?) -> Int? { (value as? NSNumber)?.intValue ?? Int(value as? String ?? "") }
}
