//
//  SDKChatClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore
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
    private var eventHandler: (@MainActor (ChatEvent) -> Void)?

    /// 当前登录所有者由runtime注入，避免相同UID重新登录误接旧请求。
    init(validSession: @escaping @MainActor (ChatContext) -> Bool) { self.validSession = validSession }

    /// SDK数据库访问前核对租户、UID、登录轮次和数据库就绪。
    func validate(_ context: ChatContext) throws {
        guard self.context == context, validSession(context), sdk.myUserID() == context.userUID,
              sdk.isUserDatabaseReady() else { throw ChatClientError.sessionExpired }
    }

    /// 本地历史分页使用SDK固定100条查询，不构造独立消息库。
    func cached(context: ChatContext, offset: Int) throws -> [ChatMessageRecord] {
        try validate(context)
        return (sdk.toolGetChatMessageHistory(with: context.route.id, offset: offset) as? [NoaIMChatMessageModel] ?? [])
            .map { SDKChatMessageMapper.record($0, userUID: context.userUID) }
    }

    /// 独立SDK代理只绑定当前聊天，会话关闭即释放。
    func observe(context: ChatContext, onEvent: @escaping @MainActor (ChatEvent) -> Void) {
        stop(); self.context = context; eventHandler = onEvent
        let run = generation
        let delegate = SDKChatDelegate(userUID: context.userUID, conversationID: context.route.id, sourceGroupID: context.route.sourceGroupID) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, self.generation == run, self.validSession(context) else { return }
                if case .permissionsChanged = event, context.route.kind == .group {
                    self.groupDetail = nil; self.groupMute = nil
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
        generation = UUID()
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
        let json = try await request(context: context) { success, failure in
            if context.route.kind == .group { self.sdk.queryGroupMsgRecord(NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure) }
            else { self.sdk.querySingleMsgRecord(NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure) }
        }
        try validate(context)
        guard ChatRuntime.shared.contentRevision(context) == contentAtStart else { throw CancellationError() }
        guard let rows = json["rows"] as? [[String: Any]] else { throw ChatClientError.invalidResponse }
        var mapped: [ChatMessageRecord] = []
        // 只有当前轮次持有SDK锁，转换与落库不会污染另一账号数据库。
        objc_sync_enter(sdk)
        defer { objc_sync_exit(sdk) }
        try validate(context)
        for row in rows {
            let model = SDKChatMessageMapper.historyModel(row, context: context)
            let record = SDKChatMessageMapper.record(model, userUID: context.userUID)
            guard record.conversationID == context.route.id else { continue }
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
                if old.messageStatus != 1 { target.messageStatus = old.messageStatus }
                else if model.messageStatus != 1 { target.messageStatus = model.messageStatus }
                target.chatMessageReaded = old.chatMessageReaded || model.chatMessageReaded
                target.haveReadCount = max(old.haveReadCount, model.haveReadCount)
                target.totalNeedReadCount = max(old.totalNeedReadCount, model.totalNeedReadCount)
                if old.messageSendType.rawValue == 1 { target.messageSendType = old.messageSendType; target.msgID = old.msgID; target.sendTime = max(old.sendTime, model.sendTime) }
            }
            sdk.toolInsertOrUpdateChatMessage(with: target)
            mapped.append(SDKChatMessageMapper.record(target, userUID: context.userUID))
        }
        return ChatPage(messages: mapped, hasMore: rows.count >= 100)
    }

    /// 发请求前记录当前完整SDK缓存版本，回写时识别等待期间的编辑、已读和删除。
    private func cacheSnapshot(context: ChatContext) throws -> [String: ChatMessageRecord] {
        try validate(context); var values: [String: ChatMessageRecord] = [:]; var offset = 0
        while true {
            let rows = sdk.toolGetChatMessageHistory(with: context.route.id, offset: offset) as? [NoaIMChatMessageModel] ?? []
            for model in rows { let item = SDKChatMessageMapper.record(model, userUID: context.userUID); if !item.serverID.isEmpty { values["s:" + item.serverID] = item }; if !item.localID.isEmpty { values["m:" + item.localID] = item } }
            if rows.count < 100 { break }; offset += rows.count
        }
        return values
    }

    /// 群详情提供本人禁言时间和userInGroup，缓存群表缺失这些字段时不猜可发送。
    private func refreshGroup(context: ChatContext) async throws {
        let json = try await request(context: context) { success, failure in
            self.sdk.getGroupInfo(with: ["groupId": context.route.id, "userUid": context.userUID], onSuccess: success, onFailure: failure)
        }
        let mute = try await request(context: context) { success, failure in
            self.sdk.groupGetUserNotalkState(with: NSMutableDictionary(dictionary: ["groupId": context.route.id, "userUid": context.userUID]), onSuccess: success, onFailure: failure)
        }
        try validate(context); groupDetail = json; groupMute = mute; updateGroupCache(json, context: context)
    }

    /// 管理与转发只刷新权限接口，避免为发送检查重复补页聊天历史。
    func refreshPermissions(context: ChatContext) async throws {
        try validate(context)
        if context.route.kind == .group { try await refreshGroup(context: context) }
    }

    /// 真实群详情同步SDK群表和会话标题，让来源群私聊守卫立即读取最新策略。
    func updateGroupCache(_ json: [String: Any], context: ChatContext) {
        guard validSession(context), let group = (sdk.toolCheckMyGroup(with: context.route.id) as LingIMGroupModel?) else { return }
        group.groupName = json["groupName"] as? String ?? group.groupName
        group.groupAvatar = json["groupAvatar"] as? String ?? group.groupAvatar
        group.userGroupRole = (json["userGroupRole"] as? NSNumber)?.intValue ?? Int(json["userGroupRole"] as? String ?? "") ?? 0
        group.groupStatus = (json["groupStatus"] as? NSNumber)?.intValue ?? Int(json["groupStatus"] as? String ?? "") ?? 0
        group.leaveGroupStatus = (json["userInGroup"] as? NSNumber)?.boolValue == true ? 0 : 1
        group.isPrivateChat = (json["isPrivateChat"] as? NSNumber)?.boolValue ?? false
        group.isNetCall = (json["isNetCall"] as? NSNumber)?.boolValue ?? false
        group.isGroupChat = (json["isGroupChat"] as? NSNumber)?.boolValue ?? false
        group.isNeedVerify = (json["isNeedVerify"] as? NSNumber)?.boolValue ?? false
        group.isShowHistory = (json["isShowHistory"] as? NSNumber)?.boolValue ?? false
        group.isShowQrCode = (json["isShowQrCode"] as? NSNumber)?.boolValue ?? false
        group.closeSearchUser = (json["closeSearchUser"] as? NSNumber)?.boolValue ?? group.closeSearchUser
        sdk.toolInsertOrUpdateGroupModel(with: group)
        if let session = (sdk.toolCheckMySession(with: context.route.id) as LingIMSessionModel?) {
            session.sessionName = group.groupName; session.sessionAvatar = group.groupAvatar; sdk.toolUpdateSession(with: session)
        }
    }

    /// 配置和SDK群库每次重新读取，旧菜单不能绕过刚发生的禁言降权。
    func permissions(context: ChatContext) throws -> ChatPermission {
        try validate(context)
        let authority = UserRoleAuthorityStore.shared.current
        let config = OSSConnectionBootstrap.shared.current.flatMap { SystemConfigStore.shared.load(apiHost: $0.apiHost) }
        let recallMinutes = Double(config?.messageRecallTime ?? "0") ?? 0
        let editMinutes = authority?.positiveMinutes("edited_message_sent") ?? 0
        var value = ChatPermission(canUpload: authority?.allows("upImageVideoFile") == true, canUploadFile: authority?.allows("upFile") == true,
            canDelete: authority?.allows("deleteMessage") == true,
            canDeleteBoth: authority?.allows("remoteDeleteMessage") == true,
            canRecallOthers: config?.groupMangerMessageRecallTime == "1",
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
                value.canSend = friend?.status == 1 && friend?.disableStatus != 4
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
            value.sendInterval = Double((config?.groupMessageInterval ?? 0) > 0 ? config!.groupMessageInterval : 2000) / 1000
            let verified = groupDetail != nil
            let inGroup = (groupDetail?["userInGroup"] as? NSNumber)?.boolValue ?? false
            let personalMuted = (groupMute?["isGroupForbid"] as? NSNumber)?.intValue == 1
            let allMuted = (groupMute?["isGroupChat"] as? NSNumber)?.intValue == 1 || group.isGroupChat
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
        model.filePath = message.resource; model.fileName = message.fileName; model.showFileName = message.fileName; model.fileSize = Float(message.size)
        return model
    }

    /// 文件类型沿旧MIME映射，未识别扩展发送unknow而非随意造类型。
    private func legacyFileType(_ name: String) -> String {
        let mime = UTType(filenameExtension: URL(fileURLWithPath: name).pathExtension)?.preferredMIMEType ?? ""
        let mapping = ["image/jpeg": "jpeg", "image/png": "png", "application/msword": "doc", "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "docx", "application/vnd.ms-excel": "xls", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": "xlsx", "application/vnd.ms-powerpoint": "ppt", "application/vnd.openxmlformats-officedocument.presentationml.presentation": "pptx", "application/zip": "zip", "application/x-rar-compressed": "rar", "text/plain": "txt", "application/pdf": "pdf", "video/mp4": "mp4", "video/quicktime": "mov", "video/avi": "avi", "video/x-flv": "flv", "application/vnd.rn-realmedia": "rm", "application/vnd.rn-realmedia-vbr": "rmvb", "video/x-matroska": "mkv", "video/x-ms-wmv": "wmv"]
        return mapping[mime] ?? "unknow"
    }

    /// 正文已读仅发送可见收到的服务端ID；不预先伪造群已读人数。
    func read(_ messages: [ChatMessageRecord], context: ChatContext) async throws {
        try validate(context)
        let ids = messages.filter { $0.senderID != context.userUID && $0.isBody && !$0.serverID.isEmpty }.map(\.serverID)
        guard !ids.isEmpty else { return }
        let model = NoaIMChatMessageModel()
        model.msgID = UUID().uuidString; model.fromID = context.userUID; model.toID = context.route.id
        model.messageType = CIMChatMessageType(rawValue: 13)!; model.chatType = CIMChatType(rawValue: context.route.kind == .group ? 1 : 0)!
        model.sMsgIdArray = NSMutableArray(array: ids); model.isAck = false; model.sendTime = Int64(Date().timeIntervalSince1970 * 1000)
        sdk.toolSendChatMessage(with: model)
        for item in messages {
            if let original = (sdk.toolGetOneChatMessage(withMessageID: item.localID, sessionID: context.route.id) as NoaIMChatMessageModel?) { sdk.toolMessageHaveRead(with: original) }
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
            if message.state == .failed && action == .delete {
                if let model = (sdk.toolGetOneChatMessage(withMessageID: message.localID, sessionID: context.route.id) as NoaIMChatMessageModel?) { sdk.toolDeleteChatMessage(with: model) }; return
            }
            params["operationStatus"] = action == .delete ? 1 : 2
            params["msgIdList"] = [message.serverID]; params["msgId"] = ""; params["sMsgId"] = ""
            _ = try await request(context: context) { success, failure in self.sdk.deleteMessage(NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure) }
        } else if action == .recall {
            params["uid"] = message.senderID; params["status"] = 2; params["operateNick"] = UserSessionStore.shared.currentUser?.nickname ?? ""
            let result = try await request(context: context) { success, failure in self.sdk.recallMessage(NSMutableDictionary(dictionary: params), onSuccess: success, onFailure: failure) }
            guard (result["_value"] as? NSNumber)?.boolValue == true else { throw ChatClientError.unavailable("撤回未被服务器确认，请重试") }
        } else { throw ChatClientError.unavailable("此操作需要通过对应编辑或转发页面完成") }
        try validate(context)
        if let model = (sdk.toolGetOneChatMessage(withMessageID: message.localID, sessionID: context.route.id) as NoaIMChatMessageModel?) {
            model.messageStatus = action == .recall ? 2 : 0; sdk.toolInsertOrUpdateChatMessage(with: model)
        }
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
