//
//  SDKChatClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore
import MMKV
import UniformTypeIdentifiers
import ObjectiveC

/// 消息请求复用SDK签名；历史回调先校验身份再转模型与写入数据库。
@MainActor final class SDKChatClient: ChatClient {
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }
    private var delegate: SDKChatDelegate?
    private var context: ChatContext?
    private var generation = UUID()
    private let validSession: @MainActor (ChatContext) -> Bool
    private var waiting: [UUID: () -> Void] = [:]
    private var groupDetail: [String: Any]?
    private var groupMute: [String: Any]?
    private var groupRefreshRevision = UUID()
    private var muteExpiryRevision = UUID()
    private var muteExpiryTask: Task<Void, Never>?
    private var muteExpiryState = ChatGroupMuteExpiryState()
    private var eventHandler: (@MainActor (ChatEvent) -> Void)?

    /// 当前登录所有者由runtime注入，避免相同UID重新登录误接旧请求。
    init(validSession: @escaping @MainActor (ChatContext) -> Bool) { self.validSession = validSession }

    /// SDK数据库访问前核对租户、UID、登录轮次和数据库就绪。
    func validate(_ context: ChatContext) throws {
        guard self.context == context, validSession(context), sdk.myUserID() == context.userUID,
              sdk.isUserDatabaseReady() else { throw ChatClientError.sessionExpired }
    }

    /// 对齐旧端进入单/群聊的会话清读；正文已读和语音播放状态仍由read单独处理。
    func clearConversationUnread(context: ChatContext, onFailure: @escaping @MainActor (String) -> Void) throws {
        objc_sync_enter(sdk)
        defer { objc_sync_exit(sdk) }
        try validate(context)
        guard context.route.kind == .single || context.route.kind == .group,
              let current = (sdk.toolCheckMySession(with: context.route.id) as LingIMSessionModel?) else { return }
        let latest = current.sessionLatestServerMsgID?.isEmpty == false
            ? current.sessionLatestServerMsgID ?? ""
            : (current.sessionLatestMessage ?? sdk.toolGetLatestChatMessage(withSessionID: context.route.id))?.serviceMsgID ?? ""
        let checkpoint = ChatRuntime.shared.beginReadCountClear(context: context, count: current.sessionUnreadCount, boundaryID: latest)
        if current.sessionUnreadCount != 0 || current.readTag != 0 {
            current.sessionUnreadCount = 0; current.readTag = 0
            guard sdk.toolUpdateSession(with: current) else {
                throw ChatClientError.unavailable("本机会话未读数未能清除，请返回聊天后重试")
            }
        }
        // 本机清除成功即撤销原计数成员，避免随后正文已读再扣到新到消息。
        if let checkpoint {
            ChatRuntime.shared.confirmReadCountClear(checkpoint, context: context, count: 0, latestID: latest)
        }
        // 复用旧端与SDK的重连清读边界；仅记录打开时的SID，保留其它会话已有记录。
        if !latest.isEmpty {
            let key = "clearReadNumSMsgIdDictKey"
            var boundaries = MMKV.default()?.object(of: NSDictionary.self, forKey: key) as? [String: String] ?? [:]
            boundaries[context.route.id] = latest
            _ = MMKV.default()?.set(boundaries as NSDictionary, forKey: key)
            sdk.clearReadNumSMsgIdDict = boundaries
        }
        var values: [String: Any] = ["userUid": context.userUID, "peerUid": context.route.id,
                                     "dialogType": context.route.kind == .group ? 1 : 0, "readTag": 0]
        if !latest.isEmpty { values["latestSMsgId"] = latest }
        let run = generation
        let reportFailure: @Sendable (String) -> Void = { [weak self] message in
            Task { @MainActor [weak self] in
                guard let self, self.generation == run, (try? self.validate(context)) != nil else { return }
                onFailure(message)
            }
        }
        // 此接口只转发运输请求，不自行写库；成功回执不回写旧快照，保留后来到达的新消息。
        sdk.conversationReadedStatus(NSMutableDictionary(dictionary: values), onSuccess: { data, _ in
            let accepted = data == nil || data is NSNull || (data as? NSNumber) == 1
            if !accepted { reportFailure("会话已读同步未被接受，请返回聊天后重试") }
        }, onFailure: { code, _, _ in
            reportFailure("会话已读同步失败（\(code)），请返回聊天后重试")
        })
    }

    /// 本地历史分页使用SDK固定100条查询，不构造独立消息库。
    func cached(context: ChatContext, offset: Int) throws -> [ChatMessageRecord] {
        try validate(context)
        if offset == 0 { try flushReadTransitions(context: context); try clearManualReadTag(context: context) }
        let models = sdk.toolGetChatMessageHistory(with: context.route.id, offset: offset) as? [NoaIMChatMessageModel] ?? []
        let records = models.map { SDKChatMessageMapper.record($0, userUID: context.userUID) }
        var recallTargets: [String: String] = [:]
        for (model, record) in zip(models, records) where record.type == 8 {
            if let target = model.backDelServiceMsgID, !target.isEmpty { recallTargets[record.id] = target }
        }
        // 旧端SDK已把撤回控制条持久化，并将原条标为status2。缓存页未带原条时，
        // 用本机原条替换隐藏的控制条，避免首屏完成后远端历史才补出“消息已撤回”。
        return ChatRecallCache.reconcile(records, targets: recallTargets) { target in
            guard let model = sdk.toolGetOneChatMessage(withServiceMessageID: target, sessionID: context.route.id) as NoaIMChatMessageModel? else { return nil }
            return SDKChatMessageMapper.record(model, userUID: context.userUID)
        }
    }

    /// 独立SDK代理只绑定当前聊天，会话关闭即释放。
    func observe(context: ChatContext, onEvent: @escaping @MainActor (ChatEvent) -> Void) {
        stop(); self.context = context; eventHandler = onEvent
        let run = generation
        let delegate = SDKChatDelegate(userUID: context.userUID, conversationID: context.route.id, sourceGroupID: context.route.sourceGroupID, isGroup: context.route.kind == .group) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, self.generation == run, self.validSession(context) else { return }
                if case .permissionsChanged = event, context.route.kind == .group {
                    self.groupDetail = nil; self.groupMute = nil
                    self.muteExpiryTask?.cancel(); self.muteExpiryTask = nil; self.muteExpiryRevision = UUID()
                    Task { try? await self.refreshGroup(context: context); if self.generation == run { onEvent(.permissionsChanged) } }
                }
                if case .memberHistoryDeleted(let ids) = event {
                    ChatRuntime.shared.removedMemberMessages(ids, context: context)
                    for id in ids { self.sdk.toolDeleteGroupMemberAllSendMessage(with: id, groupID: context.route.id) }
                }
                if case .cleared = event { ChatRuntime.shared.markCleared(context) }
                onEvent(event)
            }
        }
        self.delegate = delegate
        sdk.addMessageDelegate(delegate); sdk.addGroupDelegate(delegate); sdk.addUserDelegate(delegate)
    }

    /// 同步撤销等待、代理和群详情，迟到回调只被丢弃。
    func stop() {
        generation = UUID(); groupRefreshRevision = UUID(); muteExpiryRevision = UUID()
        muteExpiryTask?.cancel(); muteExpiryTask = nil; muteExpiryState = ChatGroupMuteExpiryState()
        for cancel in waiting.values { cancel() }; waiting.removeAll()
        if let delegate { sdk.removeMessageDelegate(delegate); sdk.removeGroupDelegate(delegate); sdk.removeUserDelegate(delegate) }
        delegate = nil; context = nil; eventHandler = nil; groupDetail = nil; groupMute = nil
    }

    /// 使用真实历史接口并固定pageNumber1游标分页；不调用会在旧账号回调里自行写库的helper。
    func history(context: ChatContext, before: String?, offset: Int) async throws -> ChatPage {
        try validate(context)
        if context.route.kind == .group && groupDetail == nil {
            try await refreshGroup(context: context)
            eventHandler?(.permissionsChanged)
        }
        let contentAtStart = ChatRuntime.shared.contentRevision(context)
        let cacheAtStart = try cacheSnapshot(context: context)
        var params: [String: Any] = ["pageSize": 100, "pageNumber": 1, "userUid": context.userUID]
        params[context.route.kind == .group ? "groupId" : "fromUid"] = context.route.id
        if let before, !before.isEmpty { params["sMsgId"] = before; params["isThanMsgId"] = 1 }
        let json: [String: Any]
        do {
            json = try await request(context: context) { success, failure in
                if context.route.kind == .group { self.sdk.queryGroupMsgRecord(NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure) }
                else { self.sdk.querySingleMsgRecord(NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure) }
            }
        } catch {
            try validate(context)
            guard !Task.isCancelled, ChatRuntime.shared.contentRevision(context) == contentAtStart else { throw CancellationError() }
            // 与旧端一致，网络失败仍回读本机更早一页；远端结束状态未知，保留重试。
            let local = try cached(context: context, offset: offset)
            guard !local.isEmpty else { throw error }
            return ChatPage(messages: local, hasMore: true, nextCursor: before, nextOffset: offset + local.count)
        }
        try validate(context)
        guard ChatRuntime.shared.contentRevision(context) == contentAtStart else { throw CancellationError() }
        guard let rows = json["rows"] as? [[String: Any]] else { throw ChatClientError.invalidResponse }
        var mapped: [ChatMessageRecord] = []
        var oldest: ChatMessageRecord?
        var restoredServerIDs: Set<String> = []
        #if DEBUG
        var remoteStatusCounts: [Int: Int] = [:]
        var localStatusConflicts = 0
        #endif
        // 只有当前轮次持有SDK锁，转换与落库不会污染另一账号数据库。
        objc_sync_enter(sdk)
        defer { objc_sync_exit(sdk) }
        try validate(context)
        for row in rows {
            let model = SDKChatMessageMapper.historyModel(row, context: context)
            let record = SDKChatMessageMapper.record(model, userUID: context.userUID)
            guard record.conversationID == context.route.id else { continue }
            #if DEBUG
            remoteStatusCounts[record.status.rawValue, default: 0] += 1
            #endif
            // 隐藏控制条也占远端历史位置，不能仅从最终可见正文推算下一次游标。
            if !record.serverID.isEmpty, oldest.map({ record.timestamp < $0.timestamp ||
                (record.timestamp == $0.timestamp && record.serverID.compare($0.serverID, options: .numeric) == .orderedAscending) }) ?? true {
                oldest = record
            }
            if [8, 9, 15].contains(record.type) {
                if let target = model.backDelServiceMsgID, let original = (sdk.toolGetOneChatMessage(withServiceMessageID: target, sessionID: context.route.id) as NoaIMChatMessageModel?) {
                    original.messageStatus = record.type == 8 ? 2 : 0
                    sdk.toolInsertOrUpdateChatMessage(with: original)
                    mapped.append(SDKChatMessageMapper.record(original, userUID: context.userUID))
                }
                continue
            }
            let old: NoaIMChatMessageModel? = !record.serverID.isEmpty ? sdk.toolGetOneChatMessage(withServiceMessageID: record.serverID, sessionID: context.route.id) : sdk.toolGetOneChatMessage(withMessageID: record.localID, sessionID: context.route.id)
            let baseline = cacheAtStart["s:" + record.serverID] ?? cacheAtStart["m:" + record.localID]
            let latest = old.map { SDKChatMessageMapper.record($0, userUID: context.userUID) }
            if ChatHistoryCachePolicy.wasDeletedDuringRequest(current: latest, atRequest: baseline) { continue }
            let target: NoaIMChatMessageModel
            if let old, let latest, ChatHistoryCachePolicy.keepCurrent(remote: record, current: latest, atRequest: baseline) { target = old }
            else { target = model }
            if let old {
                #if DEBUG
                if old.messageStatus != 1 && old.messageStatus != record.status.rawValue { localStatusConflicts += 1 }
                #endif
                // target已按请求开始快照判断是否保护期间变更，不能再无条件覆盖服务器状态。
                if old.messageStatus == 1 && model.messageStatus != 1 { target.messageStatus = model.messageStatus }
                if old.messageStatus != 1 && target.messageStatus == 1 && !record.serverID.isEmpty {
                    restoredServerIDs.insert(record.serverID)
                }
                target.chatMessageReaded = old.chatMessageReaded || model.chatMessageReaded
                target.haveReadCount = max(old.haveReadCount, model.haveReadCount)
                target.totalNeedReadCount = max(old.totalNeedReadCount, model.totalNeedReadCount)
                if old.messageSendType.rawValue == 1 { target.messageSendType = old.messageSendType; target.msgID = old.msgID; target.sendTime = max(old.sendTime, model.sendTime) }
            }
            sdk.toolInsertOrUpdateChatMessage(with: target)
            mapped.append(SDKChatMessageMapper.record(target, userUID: context.userUID))
        }
        // 云端可能只保留部分历史或限制实际页长；补拉后仍以SDK库补齐本机分页。
        // 非空短页不能证明游标已到头，空页且本机不足一页时才停止下拉。
        let local = try cached(context: context, offset: offset)
        #if DEBUG
        // 只输出分页计数，不输出聊天正文、用户或消息ID。
        print("[ChatHistory] response rows=\(rows.count) mapped=\(mapped.count) cached=\(local.count) cursorAdvanced=\(oldest?.serverID != before)")
        let statusCounts = Dictionary(grouping: mapped, by: { $0.status.rawValue }).map { "\($0.key):\($0.value.count)" }.sorted().joined(separator: ",")
        let typeCounts = Dictionary(grouping: mapped, by: \.type).map { "\($0.key):\($0.value.count)" }.sorted().joined(separator: ",")
        let remoteStatuses = remoteStatusCounts.map { "\($0.key):\($0.value)" }.sorted().joined(separator: ",")
        print("[ChatHistory] remoteStatus=[\(remoteStatuses)] localStatusConflicts=\(localStatusConflicts)")
        print("[ChatHistory] mappedStatus=[\(statusCounts)] mappedType=[\(typeCounts)] visibleCandidates=\(mapped.filter(\.isVisible).count)")
        #endif
        return ChatPage(messages: ChatMessageMerge.merge(local, with: mapped), hasMore: !rows.isEmpty || local.count == 100,
                        nextCursor: oldest?.serverID, nextOffset: offset + local.count, restoredServerIDs: restoredServerIDs)
    }

    /// 发请求前记录当前完整SDK缓存版本，回写时识别等待期间的编辑、已读和删除。
    private func cacheSnapshot(context: ChatContext) throws -> [String: ChatMessageRecord] {
        try validate(context); var values: [String: ChatMessageRecord] = [:]; var offset = 0
        while true {
            let rows = sdk.toolGetChatMessageHistoryIncludingInactive(with: context.route.id, offset: offset) as? [NoaIMChatMessageModel] ?? []
            for model in rows { let item = SDKChatMessageMapper.record(model, userUID: context.userUID); if !item.serverID.isEmpty { values["s:" + item.serverID] = item }; if !item.localID.isEmpty { values["m:" + item.localID] = item } }
            if rows.count < 100 { break }; offset += rows.count
        }
        return values
    }

    /// 群详情提供本人禁言时间和userInGroup，缓存群表缺失这些字段时不猜可发送。
    private func refreshGroup(context: ChatContext) async throws {
        try validate(context)
        let revision = UUID(); groupRefreshRevision = revision
        let json = try await request(context: context) { success, failure in
            self.sdk.getGroupInfo(with: ["groupId": context.route.id, "userUid": context.userUID], onSuccess: success, onFailure: failure)
        }
        let mute = try await request(context: context) { success, failure in
            self.sdk.groupGetUserNotalkState(with: NSMutableDictionary(dictionary: ["groupId": context.route.id, "userUid": context.userUID]), onSuccess: success, onFailure: failure)
        }
        try validate(context)
        guard groupRefreshRevision == revision else { throw CancellationError() }
        #if DEBUG
        // 只诊断三个权限状态，不打印群资料、UID、请求或响应正文。
        print("[ChatGroupPermission] " + ChatGroupPermissionPayload.diagnostic(detail: json, mute: mute))
        #endif
        guard ChatGroupPermissionPayload.verified(detail: json, mute: mute) else { throw ChatClientError.invalidResponse }
        groupDetail = json; groupMute = mute; updateGroupCache(json, context: context)
        scheduleMuteExpiry(context: context)
    }

    /// 管理与转发只刷新权限接口，避免为发送检查重复补页聊天历史。
    func refreshPermissions(context: ChatContext) async throws {
        try validate(context)
        if context.route.kind == .group { try await refreshGroup(context: context) }
    }

    /// 真实群详情同步SDK群表和会话标题，让来源群私聊守卫立即读取最新策略。
    func updateGroupCache(_ json: [String: Any], context: ChatContext) {
        guard validSession(context), let group = (sdk.toolCheckMyGroup(with: context.route.id) as LingIMGroupModel?) else { return }
        let previousCount = group.memberCount
        if let count = Int((json["memberCount"] as? NSNumber)?.stringValue ?? json["memberCount"] as? String ?? ""), count > 0 {
            group.memberCount = count
        }
        group.groupName = json["groupName"] as? String ?? group.groupName
        group.groupAvatar = json["groupAvatar"] as? String ?? group.groupAvatar
        group.userGroupRole = (json["userGroupRole"] as? NSNumber)?.intValue ?? Int(json["userGroupRole"] as? String ?? "") ?? 0
        group.groupStatus = (json["groupStatus"] as? NSNumber)?.intValue ?? Int(json["groupStatus"] as? String ?? "") ?? 0
        group.leaveGroupStatus = ChatGroupPermissionPayload.boolean(json["userInGroup"]) == true ? 0 : 1
        group.isPrivateChat = ChatGroupPermissionPayload.boolean(json["isPrivateChat"]) ?? true
        group.isNetCall = ChatGroupPermissionPayload.boolean(json["isNetCall"]) ?? false
        group.isGroupChat = ChatGroupPermissionPayload.boolean(json["isGroupChat"]) ?? true
        group.isNeedVerify = ChatGroupPermissionPayload.boolean(json["isNeedVerify"]) ?? true
        group.isShowHistory = ChatGroupPermissionPayload.boolean(json["isShowHistory"]) ?? false
        group.isShowQrCode = ChatGroupPermissionPayload.boolean(json["isShowQrCode"]) ?? false
        group.closeSearchUser = ChatGroupPermissionPayload.boolean(json["closeSearchUser"]) ?? group.closeSearchUser
        if sdk.toolInsertOrUpdateGroupModel(with: group), group.memberCount != previousCount {
            // 单纯写群表不会发代理；人数实际变化时通知列表，避免重启后才更新。
            // 相同人数不重复通知，防止聊天权限刷新与群代理形成回查循环。
            sdk.groupDelegate.cimToolGroupUpdate?(with: group)
        }
        if let session = (sdk.toolCheckMySession(with: context.route.id) as LingIMSessionModel?) {
            session.sessionName = group.groupName; session.sessionAvatar = group.groupAvatar; sdk.toolUpdateSession(with: session)
        }
    }

    /// 配置和SDK缓存每次重读；好友库未持久化status，正常行默认0，删除由SDK物理移除，来源群禁私聊仍独立校验。
    func permissions(context: ChatContext) throws -> ChatPermission {
        try validate(context)
        let authority = UserRoleAuthorityStore.shared.current
        let recallMinutes = LocalMessagingSettings.messageRecallMinutes
        let editMinutes = authority?.positiveMinutes("edited_message_sent") ?? 0
        var value = ChatPermission(canUpload: authority?.allows("upImageVideoFile") == true, canUploadFile: authority?.allows("upFile") == true,
            // 旧端任一删除权限都会开放“从我的设备删除”；remoteDeleteMessage 另外控制双方删除。
            canDelete: authority?.allows("deleteMessage") == true || authority?.allows("remoteDeleteMessage") == true,
            canDeleteBoth: authority?.allows("remoteDeleteMessage") == true,
            canRecallOthers: LocalMessagingSettings.managersCanRecallOthers,
            canRecall: recallMinutes > 0, canEdit: editMinutes > 0,
            canPin: authority?.allows(context.route.kind == .group ? "group_msg_pinning" : "user_dialog_msg_pinning") == true,
            isGroup: context.route.kind == .group,
            recallWindow: recallMinutes > 0 ? recallMinutes * 60 : nil,
            editWindow: editMinutes > 0 ? Double(editMinutes * 60) : nil)
        if context.route.kind == .single {
            if context.route.id == "100002" {
                value.canSend = authority?.allows("isShowFileAssistant") == true
                if !value.canSend { value.reason = "文件助手权限已关闭" }
            } else {
                let friend: LingIMFriendModel? = sdk.toolCheckMyFriend(with: context.route.id)
                value.canSend = [0, 1].contains(friend?.status ?? -1) && friend?.disableStatus != 4
                if !value.canSend { value.reason = "当前好友关系不可用，请返回资料页确认" }
            }
        }
        if let sourceID = context.route.sourceGroupID {
            let source: LingIMGroupModel? = sdk.toolCheckMyGroup(with: sourceID)
            guard let source, source.groupStatus == 1, source.leaveGroupStatus == 0,
                  source.userGroupRole > 0 || !source.isPrivateChat || authority?.allows("groupSecurity") == true else {
                value.canSend = false; value.isActive = false; value.reason = "来源群当前禁止成员私聊"; return value
            }
        }
        if context.route.kind == .group {
            guard let group = (sdk.toolCheckMyGroup(with: context.route.id) as LingIMGroupModel?) else { value.canSend = false; value.isActive = false; value.reason = "群资料尚不可用"; return value }
            value.role = [0, 1, 2].contains(group.userGroupRole) ? group.userGroupRole : 0; value.isPrivateChat = group.isPrivateChat
            value.isActive = group.groupStatus == 1 && group.leaveGroupStatus == 0
            value.sendInterval = Double(LocalMessagingSettings.groupMessageIntervalMilliseconds) / 1000
            let verified = groupDetail != nil && groupMute != nil
            let inGroup = ChatGroupPermissionPayload.boolean(groupDetail?["userInGroup"]) ?? false
            let personalMuted = groupMute.flatMap { ChatGroupPermissionPayload.personalMuted($0) } ?? true
            // 禁言接口在详情之后返回，使用这份最新状态，避免旧群缓存阻止已解除禁言的成员。
            let allMuted = ChatGroupPermissionPayload.boolean(groupMute?["isGroupChat"]) ?? true
            value.canSend = value.isActive && verified && inGroup && !personalMuted && (value.role > 0 || !allMuted)
            value.reason = !value.isActive ? "已离开群聊或群聊已停用" : (!verified ? "正在确认群发送权限" : "当前已被禁言")
            if !value.canSend { value.canUpload = false; value.canUploadFile = false }
        }
        return value
    }

    /// 沿旧SDK敏感词替换规则，@先变UID协议以保护重名身份和位置。
    func prepareMessage(_ message: ChatMessageRecord, context: ChatContext) throws -> ChatMessageRecord {
        try validate(context)
        guard [0, 10].contains(message.type) else { return message }
        let words = sdk.toolGetSensitiveList().filter { $0.status == 0 && [0, 1].contains($0.sceneType) && $0.filterType == 1 }.map { $0.decodeWordText ?? "" }.filter { !$0.isEmpty }
        var result = message
        var content = message.type == 10 ? ChatMentionEngine.wireText(message.text, segments: message.mentions) : message.text
        content = ChatMentionEngine.filterSensitive(content, words: words)
        if message.type == 10 {
            var names: [String: String] = [:]; for item in message.mentions { names[item.userUID] = item.name }
            let display = ChatMentionEngine.renderWire(content, names: names); result.text = display.0; result.mentions = display.1
        } else { result.text = content }
        return result
    }

    /// SDK原消息ID用于重发，附件必须已经取得真实资源地址。
    func send(_ message: ChatMessageRecord, context: ChatContext) throws {
        try validate(context)
        let permission = try permissions(context: context)
        guard permission.canSend, permission.isActive else { throw ChatClientError.permission(permission.reason) }
        if [1, 2, 5].contains(message.type) {
            let key = message.type == 5 ? "upFile" : "upImageVideoFile"
            let authority = UserRoleAuthorityStore.shared.current
            guard authority?.allows(key) == true, ChatAttachmentPolicy.allowedBytes(message.size, maximumMB: Int64(authority?.configurationData[key] ?? "") ?? 0) else { throw ChatClientError.permission("附件上传权限或大小限制已变化，请重新选择") }
        }
        let model = makeModel(message, context: context)
        sdk.toolSendChatMessage(with: model)
        let saved: NoaIMChatMessageModel? = sdk.toolGetOneChatMessage(withMessageID: message.localID, sessionID: context.route.id)
        guard saved != nil else { throw ChatClientError.unavailable("消息未能保存，请重试") }
    }

    /// 上传失败写入现有SDK消息表，本机路径只写local字段，不作为云资源发送。
    func saveFailedMedia(_ message: ChatMessageRecord, context: ChatContext) throws {
        try validate(context)
        guard [1, 2].contains(message.type), message.senderID == context.userUID,
              message.conversationID == context.route.id, message.state == .failed,
              message.localMediaFileURL.flatMap({ ChatUploadFiles.localURL($0.path) }) != nil else { throw ChatClientError.invalidResponse }
        let existing: NoaIMChatMessageModel? = sdk.toolGetOneChatMessage(withMessageID: message.localID, sessionID: context.route.id)
        if let existing, existing.messageStatus != 1 || existing.messageSendType.rawValue == 1 { return }
        let model = makeModel(message, context: context)
        model.messageSendType = CIMChatMessageSendType(rawValue: UInt(ChatSendState.failed.rawValue))!
        model.localImgName = message.type == 1 ? ChatUploadFiles.storedPath(message.localMediaFileURL) : nil
        model.localVideoName = message.type == 2 ? ChatUploadFiles.storedPath(message.localMediaFileURL) : nil
        model.localVideoCover = message.type == 2 ? ChatUploadFiles.storedPath(message.localMediaPreviewURL) : nil
        guard sdk.toolInsertOrUpdateChatMessage(with: model) else { throw ChatClientError.unavailable("失败消息保存失败，请保留当前聊天后重试") }
    }

    /// 只更新同一消息当前结果的展示标记，迟到动画不能标记重试后的新结果。
    func markGameAnimationPlayed(_ message: ChatMessageRecord, context: ChatContext) throws {
        try validate(context)
        let model: NoaIMChatMessageModel? = !message.localID.isEmpty
            ? sdk.toolGetOneChatMessage(withMessageID: message.localID, sessionID: context.route.id)
            : sdk.toolGetOneChatMessage(withServiceMessageID: message.serverID, sessionID: context.route.id)
        guard let model, model.messageStatus == 1, model.messageType.rawValue == 21,
              Int(model.gameSticekersType) == message.gameType, model.gameStickersResut == message.text,
              model.sendTime == message.timestamp else { return }
        let previous = model.isGameAnimationed; model.isGameAnimationed = true
        guard sdk.toolInsertOrUpdateChatMessage(with: model) else {
            model.isGameAnimationed = previous
            throw ChatClientError.unavailable("游戏展示状态保存失败")
        }
    }

    /// 消息模型完整填写ACK与身份，正文继续走SDK发送和持久化。
    func makeModel(_ message: ChatMessageRecord, context: ChatContext) -> NoaIMChatMessageModel {
        let model = NoaIMChatMessageModel()
        model.msgID = message.localID; model.serviceMsgID = message.serverID
        model.fromID = context.userUID; model.toID = context.route.id
        model.fromNickname = UserSessionStore.shared.currentUser?.nickname ?? ""; model.fromIcon = UserSessionStore.shared.currentUser?.avatar ?? ""
        model.chatType = CIMChatType(rawValue: context.route.kind == .group ? 1 : 0)!
        model.messageType = CIMChatMessageType(rawValue: UInt(message.type)) ?? CIMChatMessageType(rawValue: 0)!
        model.messageSendType = CIMChatMessageSendType(rawValue: 0)!
        model.messageStatus = 1; model.isAck = true; model.isEncry = false; model.currentVersionMessageOK = true
        model.sendTime = message.timestamp; model.referenceMsgId = message.referenceID
        if message.type == 21 {
            model.gameSticekersType = Int32(message.gameType)
            model.gameStickersResut = message.text; model.gameStickersExt = ""
            model.isGameAnimationed = message.gameAnimationPlayed
        }
        model.textContent = message.text
        if message.type == 10 {
            model.atContent = ChatMentionEngine.wireText(message.text, segments: message.mentions)
            model.showContent = message.text
            model.atUsersInfoList = message.mentions.map { [$0.userUID: $0.name] }
        }
        model.imgName = message.resource; model.thumbnailImg = message.thumbnail; model.imgSize = Float(message.size); model.imgWidth = Float(message.mediaWidth); model.imgHeight = Float(message.mediaHeight)
        model.videoName = message.resource; model.videoCover = message.thumbnail; model.videoLength = Float(message.duration); model.videoCoverW = Float(message.mediaWidth); model.videoCoverH = Float(message.mediaHeight)
        model.voiceName = message.resource; model.voiceLength = Float(message.duration); model.voiceExt = "m4a"
        model.videoSize = Float(message.size)
        model.stickersImg = message.resource; model.stickersThumbnailImg = message.thumbnail; model.stickersId = message.stickerID; model.isStickersSet = message.isStickerSet; model.stickersSize = message.size; model.stickersWidth = Float(message.mediaWidth); model.stickersHeight = Float(message.mediaHeight)
        model.fileType = legacyFileType(message.fileName)
        model.filePath = message.resource
        // SDK接收时只移除首个'-'前的协议前缀；UUID先去连字符，否则会把UUID残段或原名首段当显示名。
        model.fileName = message.type == 5 ? message.localID.replacingOccurrences(of: "-", with: "") + "-" + message.fileName : message.fileName
        model.showFileName = message.fileName; model.fileSize = Float(message.size)
        return model
    }

    /// 文件类型沿旧MIME映射，未识别扩展发送unknow而非随意造类型。
    private func legacyFileType(_ name: String) -> String {
        let mime = UTType(filenameExtension: URL(fileURLWithPath: name).pathExtension)?.preferredMIMEType ?? ""
        let mapping = ["image/jpeg": "jpeg", "image/png": "png", "application/msword": "doc", "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "docx", "application/vnd.ms-excel": "xls", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": "xlsx", "application/vnd.ms-powerpoint": "ppt", "application/vnd.openxmlformats-officedocument.presentationml.presentation": "pptx", "application/zip": "zip", "application/x-rar-compressed": "rar", "text/plain": "txt", "application/pdf": "pdf", "video/mp4": "mp4", "video/quicktime": "mov", "video/avi": "avi", "video/x-flv": "flv", "application/vnd.rn-realmedia": "rm", "application/vnd.rn-realmedia-vbr": "rmvb", "video/x-matroska": "mkv", "video/x-ms-wmv": "wmv"]
        return mapping[mime] ?? "unknow"
    }

    /// 正文已读发送可见收到的服务端ID，本地只扣当前计数集合中实际从未读转读的身份。
    func read(_ messages: [ChatMessageRecord], context: ChatContext) async throws {
        try validate(context)
        try flushReadTransitions(context: context)
        try clearManualReadTag(context: context)
        let candidates = ChatVisibleReadPolicy.candidates(messages, userUID: context.userUID, conversationID: context.route.id)
        guard !candidates.isEmpty else { return }
        objc_sync_enter(sdk)
        defer { objc_sync_exit(sdk) }
        try validate(context)
        var originals: [NoaIMChatMessageModel] = []
        var missingOriginal = false
        for item in candidates {
            let original: NoaIMChatMessageModel? = sdk.toolGetOneChatMessage(withServiceMessageID: item.serverID, sessionID: context.route.id)
            guard let original else { missingOriginal = true; continue }
            let current = SDKChatMessageMapper.record(original, userUID: context.userUID)
            if current.isRead { continue }
            guard current.serverID == item.serverID,
                  !ChatVisibleReadPolicy.candidates([current], userUID: context.userUID, conversationID: context.route.id).isEmpty else { missingOriginal = true; continue }
            originals.append(original)
        }
        guard !originals.isEmpty else {
            if missingOriginal { throw ChatClientError.unavailable("消息状态已变化，请返回聊天后重试") }
            return
        }
        let model = NoaIMChatMessageModel()
        model.msgID = UUID().uuidString; model.fromID = context.userUID; model.toID = context.route.id
        model.messageType = CIMChatMessageType(rawValue: 13)!; model.chatType = CIMChatType(rawValue: context.route.kind == .group ? 1 : 0)!
        // 三段身份取刚校验的SDK原消息，不能使用UI快照或只有服务端ID的旧格式。
        let readEntries = originals.compactMap { ChatVisibleReadPolicy.wireEntry(SDKChatMessageMapper.record($0, userUID: context.userUID)) }
        guard readEntries.count == originals.count else { throw ChatClientError.invalidResponse }
        model.sMsgIdArray = NSMutableArray(array: readEntries)
        model.isAck = false; model.sendTime = Int64(Date().timeIntervalSince1970 * 1000)
        sdk.toolSendChatMessage(with: model)
        var writeFailed = missingOriginal
        for original in originals {
            try validate(context)
            original.chatMessageReaded = true
            if sdk.toolInsertOrUpdateChatMessage(with: original), let id = original.serviceMsgID { ChatRuntime.shared.savedVisibleRead(id, context: context) }
            else { original.chatMessageReaded = false; writeFailed = true }
        }
        try validate(context)
        try flushReadTransitions(context: context)
        // type13沿用SDK无ACK上报；这里不增加haveReadCount，也不将本地写入当作服务端已读回执。
        if writeFailed { throw ChatClientError.unavailable("本机已读状态未能保存，请返回聊天后重试") }
    }

    /// 部分消息已写入但会话写失败时保留待扣身份，正文已读重试也会先修复计数。
    private func flushReadTransitions(context: ChatContext) throws {
        objc_sync_enter(sdk)
        defer { objc_sync_exit(sdk) }
        try validate(context)
        guard let current = (sdk.toolCheckMySession(with: context.route.id) as LingIMSessionModel?) else {
            if ChatRuntime.shared.hasPendingVisibleReadCount(context: context) { throw ChatClientError.unavailable("本机会话已读计数暂不可用，请返回聊天后重试") }
            return
        }
        let latest = current.sessionLatestServerMsgID?.isEmpty == false ? current.sessionLatestServerMsgID ?? "" : current.sessionLatestMessage?.serviceMsgID ?? ""
        guard let plan = ChatRuntime.shared.visibleReadCountPlan(context: context, count: current.sessionUnreadCount, latestID: latest) else { return }
        current.sessionUnreadCount = plan.remaining
        guard sdk.toolUpdateSession(with: current) else { throw ChatClientError.unavailable("本机会话已读计数未能保存，请返回聊天后重试") }
        ChatRuntime.shared.commitVisibleReadCount(plan, context: context)
    }

    /// 后续正文补读仅清本机手动标记；整会话清读由打开入口独立执行。
    private func clearManualReadTag(context: ChatContext) throws {
        objc_sync_enter(sdk)
        defer { objc_sync_exit(sdk) }
        try validate(context)
        guard let current = (sdk.toolCheckMySession(with: context.route.id) as LingIMSessionModel?), current.readTag > 0 else { return }
        current.readTag = 0
        // 不调用conversationReadedStatus，不设置服务端最新已读边界，屏外未读数原样保留。
        guard sdk.toolUpdateSession(with: current) else { throw ChatClientError.unavailable("本机未读标记未能更新，请返回聊天后重试") }
    }

    /// 禁言到期后回查真实权限；取消、换号或旧窗口失败都不能自行放开发送。
    private func scheduleMuteExpiry(context: ChatContext) {
        muteExpiryTask?.cancel(); muteExpiryTask = nil
        let revision = UUID(); muteExpiryRevision = revision
        let expiry = groupMute.flatMap { ChatGroupMuteExpiry.decode($0) }
        guard let expiry = muteExpiryState.plan(expiry, now: Date()) else { return }
        let run = generation
        muteExpiryTask = Task { [weak self] in
            do {
                while expiry.deadline > Date() {
                    let seconds = min(3600, expiry.deadline.timeIntervalSinceNow)
                    if seconds > 0 { try await Task<Never, Never>.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
                }
                guard let self, !Task.isCancelled, self.generation == run, self.muteExpiryRevision == revision else { return }
                try self.validate(context)
                self.muteExpiryState.checked(expiry); self.muteExpiryTask = nil
                try await self.refreshGroup(context: context)
                guard self.generation == run, self.validSession(context) else { return }
                self.eventHandler?(.permissionsChanged)
            } catch { /* 到期接口失败仍保留已确认禁言，不以时钟计算结果当作解禁。 */ }
        }
    }

    /// 网络回执成功后才修改SDK消息原条，删除和撤回分别维护范围。
    func perform(_ action: ChatMessageAction, message: ChatMessageRecord, context: ChatContext) async throws {
        try validate(context)
        let permission = try permissions(context: context)
        guard ChatActionPolicy.allowed(for: message, userUID: context.userUID, permission: permission).contains(action) else { throw ChatClientError.permission("当前消息不允许此操作") }
        var params: [String: Any] = ["userUid": context.userUID, "chatType": context.route.kind == .group ? 1 : 0,
            "receiveId": context.route.id, "msgId": message.localID, "sMsgId": message.serverID]
        if action == .delete || action == .deleteBoth {
            if action == .delete && (message.state != .sent || message.serverID.isEmpty || message.type == 20) {
                guard let model = (sdk.toolGetOneChatMessage(withMessageID: message.localID, sessionID: context.route.id) as NoaIMChatMessageModel?),
                    sdk.toolDeleteChatMessage(with: model) else { throw ChatClientError.unavailable("无法保存本机删除状态，请重试") }
                return
            }
            params["operationStatus"] = action == .delete ? 1 : 2
            params["msgIdList"] = [message.serverID]; params["msgId"] = ""; params["sMsgId"] = ""
            _ = try await request(context: context) { success, failure in self.sdk.deleteMessage(NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure) }
        } else if action == .recall {
            params["uid"] = message.senderID; params["status"] = 2; params["operateNick"] = UserSessionStore.shared.currentUser?.nickname ?? ""
            let result = try await request(context: context) { success, failure in self.sdk.recallMessage(NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure) }
            guard (result["_value"] as? NSNumber)?.boolValue == true else { throw ChatClientError.unavailable("撤回未被服务器确认，请重试") }
        } else { throw ChatClientError.unavailable("此操作需要通过对应编辑或转发页面完成") }
        let sdk = self.sdk
        objc_sync_enter(sdk)
        defer { objc_sync_exit(sdk) }
        try validate(context)
        var model: NoaIMChatMessageModel? = sdk.toolGetOneChatMessage(withMessageID: message.localID, sessionID: context.route.id)
        if model == nil, !message.serverID.isEmpty {
            model = sdk.toolGetOneChatMessage(withServiceMessageID: message.serverID, sessionID: context.route.id)
        }
        guard let model, SDKChatMessageMapper.record(model, userUID: context.userUID).conversationID == context.route.id else {
            throw ChatClientError.unavailable("消息已受理，但无法找到本机原消息，请刷新后重试")
        }
        // 服务端受理后必须真正写入SDK墓碑；本机失败不能只隐藏页面并宣称成功。
        if model.messageStatus != 0 { model.messageStatus = action == .recall ? 2 : 0 }
        guard sdk.toolInsertOrUpdateChatMessage(with: model) else { throw ChatClientError.unavailable("消息已受理，但无法保存本机状态，请重试") }
    }

    /// 草稿与当前SDK用户库共用隔离，不从其他俱乐部缓存恢复输入。
    func draft(context: ChatContext) throws -> ChatDraft {
        try validate(context)
        let session: LingIMSessionModel? = sdk.toolCheckMySession(with: context.route.id)
        let fields = session?.draftDict as? [String: Any] ?? [:]
        let segments = (fields["atSegmentsJSON"] as? String).flatMap { $0.data(using: .utf8) }.flatMap { try? JSONDecoder().decode([ChatMentionSegment].self, from: $0) } ?? []
        return ChatDraft(text: fields["draftContent"] as? String ?? "", referenceID: fields["referenceMsgId"] as? String ?? "", mentions: segments)
    }

    /// 保存编辑版本只更新对应会话草稿，不改消息时间和未读数。
    func saveDraft(_ draft: ChatDraft, context: ChatContext) throws {
        try validate(context)
        let session: LingIMSessionModel? = sdk.toolCheckMySession(with: context.route.id)
        guard let session else { return }
        session.draftDict = ["draftContent": draft.text, "referenceMsgId": draft.referenceID, "atSegmentsJSON": String(data: try JSONEncoder().encode(draft.mentions), encoding: .utf8) ?? "[]"]
        guard sdk.toolUpdateSession(with: session) else { throw ChatClientError.unavailable("草稿未能保存") }
    }

    /// 所有回执在身份校验后收口，取消和退出不会把旧结果写进新库。
    func request(context: ChatContext, start: ( @escaping LingIMSuccessCallback, @escaping LingIMFailureCallback) -> Void) async throws -> [String: Any] {
        try validate(context)
        let id = UUID(); let waiter = SDKChatRequestWaiter<[String: Any]>()
        let run = generation; waiting[id] = { waiter.cancel() }
        defer { waiting.removeValue(forKey: id) }
        return try await waiter.run {
            start({ [weak self] data, _ in
                Task { @MainActor in
                    guard let self, self.generation == run, self.validSession(context) else { waiter.cancel(); return }
                    if let value = data as? NSNumber, !value.boolValue { waiter.finish(.failure(ChatClientError.unavailable("操作未被服务器确认"))); return }
                    if let data { waiter.finish(.success(data as? [String: Any] ?? ["_value": data])) } else { waiter.finish(.success([:])) }
                }
            }, { [weak self] _, _, _ in
                Task { @MainActor in
                    guard let self, self.generation == run, self.validSession(context) else { waiter.cancel(); return }
                    waiter.finish(.failure(ChatClientError.unavailable("操作失败，请检查网络后重试")))
                }
            })
        }
    }
}
