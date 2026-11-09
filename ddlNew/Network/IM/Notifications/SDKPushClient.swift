import Foundation
import NoaChatCore
import ObjectiveC

@MainActor final class SDKPushClient: PushClient {
    private let writes = PushRequestLane()
    private var delegate: SDKPushDelegate?
    private var observation = UUID()
    private var sdk: NoaIMSDKManager { .sharedTool() }
    private func validate(_ identity: PushIdentity) throws {
        guard LoginSessionService.shared.maintenanceSessionID == identity.sessionID,
              sdk.myUserID() == identity.userUID, sdk.mySsoInfo() == identity.tenantID,
              sdk.isUserDatabaseReady() else { throw CancellationError() }
    }
    func bind(token: String, identity: PushIdentity) async throws {
        try validate(identity)
        try await operation(identity:identity) { success, failure in
            self.sdk.imSdkUpDeviceToken(with: self.parameters(token,identity), onSuccess:success,onFailure:failure)
        }
    }
    func unbind(token: String, identity: PushIdentity) async {
        guard (try? validate(identity)) != nil else { return }
        try? await operation(identity:identity) { success,failure in
            self.sdk.imSdkdeleteDeviceToken(with:self.parameters(token,identity),onSuccess:success,onFailure:failure)
        }
    }
    private func parameters(_ token: String, _ identity: PushIdentity) -> NSMutableDictionary {
        ["osType":1,"pushServer":"apns","pushToken":token,"userUid":identity.userUID]
    }
    func loadPreferences(identity: PushIdentity) async throws -> PushPreferences {
        await writes.barrier()
        try validate(identity)
        let waiter = SDKLoginRequestWaiter<PushPreferences>()
        return try await waiter.run {
            sdk.userGetMessageRemind(with:["userUid":identity.userUID],onSuccess:{ data,_ in
                let result = (data as? [String:Any]).flatMap(PushPreferences.decode)
                Task { @MainActor in
                    if let result { waiter.finish(.success(result)) }
                    else { waiter.finish(.failure(.invalidResponse)) }
                }
            },onFailure:{ _,_,_ in Task { @MainActor in waiter.finish(.failure(.invalidResponse)) } })
        }
    }
    func savePreferences(_ value: PushPreferences, identity: PushIdentity) async throws {
        try validate(identity)
        var params=value.parameters; params["userUid"]=identity.userUID
        // 直接复用运输接口，避开SDK包装器在迟到旧回包中写全局MMKV偏好。
        try await operation(identity:identity,requireAcknowledgement:true) { success,failure in
            NoaIMHttpManager.shared().userMessageRemindSet(with:NSMutableDictionary(dictionary:params),onSuccess:success,onFailure:failure)
        }
    }
    private func operation(identity: PushIdentity, requireAcknowledgement: Bool = false,
                           _ start: (@escaping LingIMSuccessCallback,@escaping LingIMFailureCallback)->Void) async throws {
        _ = try await writes.perform { done in
            do { try validate(identity) } catch { done(.failure(error)); return }
            start({ data,_ in
                let accepted = !requireAcknowledgement || PushPreferences.saveAccepted(data)
                Task { @MainActor in done(accepted ? .success(true):.failure(AccountLoginError.invalidResponse)) }
            }, { _,_,_ in Task { @MainActor in done(.failure(AccountLoginError.invalidResponse)) } })
        }
    }
    func observe(identity: PushIdentity, received: @escaping @MainActor (PushEvent)->Void) {
        stopObserving(); let run=observation
        let delegate=SDKPushDelegate(owner:identity) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, self.observation == run, (try? self.validate(identity)) != nil else { return }
                received(event)
            }
        }
        self.delegate=delegate; sdk.addMessageDelegate(delegate); sdk.addUserDelegate(delegate)
    }
    func stopObserving() {
        observation=UUID()
        if let delegate { sdk.removeMessageDelegate(delegate); sdk.removeUserDelegate(delegate) }
        delegate=nil
    }

    /// 通知不能直接信任标题或任意会话ID；只使用当前账号已落库的真实会话。
    static func route(for destination: PushDestination, owner: PushIdentity) -> ChatRoute? {
        let sdk=NoaIMSDKManager.sharedTool()
        guard sdk.myUserID() == owner.userUID, sdk.mySsoInfo() == owner.tenantID, sdk.isUserDatabaseReady(),
              case .chat(let id,let group)=destination,
              let session=(sdk.toolCheckMySession(with:id) as LingIMSessionModel?), Int(session.sessionType.rawValue) == (group ? 2:1) else { return nil }
        let kind: ConversationKind = group ? .group:.single
        return ChatRoute(id:id,kind:kind,title:SDKConversationsClient.displayTitle(session,id:id,kind:kind,sdk:sdk),avatarURL:session.sessionAvatar ?? "")
    }
}

nonisolated private final class SDKPushDelegate: NSObject, NoaToolMessageDelegate, NoaToolUserDelegate, @unchecked Sendable {
    let owner: PushIdentity
    let received: @Sendable (PushEvent)->Void
    init(owner:PushIdentity,received:@escaping @Sendable (PushEvent)->Void) { self.owner=owner; self.received=received }
    private var valid: Bool {
        let sdk=NoaIMSDKManager.sharedTool()
        return sdk.myUserID() == owner.userUID && sdk.mySsoInfo() == owner.tenantID && sdk.isUserDatabaseReady()
    }
    func cimToolChatMessageReceive(_ message: NoaIMChatMessageModel) {
        let sdk=NoaIMSDKManager.sharedTool(); objc_sync_enter(sdk); defer { objc_sync_exit(sdk) }
        guard valid, message.messageStatus == 1, message.fromID != owner.userUID else { return }
        let type=Int(message.messageType.rawValue), chatType=Int(message.chatType.rawValue)
        guard [0,1].contains(chatType), [0,1,2,3,4,5,6,7,10,12,18,21,1000].contains(type) else { return }
        let group=chatType == 1
        let id=(group ? message.toID:message.fromID) ?? ""
        guard !id.isEmpty else { return }
        var title=message.fromNickname ?? ""
        if group, let member=(sdk.imSdkCheckGroupMember(with:message.fromID ?? "",groupID:id) as LingIMGroupMemberModel?) { title=member.showName ?? title }
        else if !group, let friend=sdk.toolCheckMyFriend(with:id) { title=friend.showName ?? title }
        if title.isEmpty { title = group ? "群消息":"新消息" }
        let body:String
        switch type {
        case 0: body = (message.translateContent?.isEmpty == false ? message.translateContent:message.textContent) ?? ""
        case 1: body="[图片]"
        case 2: body="[视频]"
        case 3,7: body="[位置]" + (message.geoName ?? "")
        case 4: body="[语音]"
        case 5: body="[文件]"
        case 6: body="[个人名片]" + (message.cardNickName ?? "")
        case 12,21: body="[表情]"
        case 18: body="[会话记录]" + (message.forwardMessage?.title ?? "")
        case 10:
            let targets = (message.atUsersInfoList as? [[String:String]] ?? []).flatMap { $0.keys }
            let names=(message.atUsersInfoList as? [[String:String]] ?? []).reduce(into:[String:String]()) { result, values in result.merge(values) { _,new in new } }
            let text=ChatMentionEngine.renderWire(message.atContent ?? message.showContent ?? "",names:names).0
            body = PushMessageSummary.mention(title:title,text:text,targets:targets,userUID:owner.userUID)
        case 1000:
            guard group, message.serverMessage?.sMsgType.rawValue == 208 else { return }
            let info: LingIMGroupModel? = sdk.toolCheckMyGroup(with:id)
            guard PushMessageSummary.allowsGroupNotice(informStatus:info?.groupInformStatus) else { return }
            body="[群公告]"
        default: return
        }
        let stableID = message.serviceMsgID?.isEmpty == false ? message.serviceMsgID ?? "" : message.msgID ?? ""
        received(PushEvent(id:stableID,destination:.chat(id:id,group:group),title:title,body:body,
                           muted:(sdk.toolCheckMySession(with:id) as LingIMSessionModel?)?.sessionNoDisturb ?? false,fromSelf:false))
    }
    func cimToolUserFriendInvite(_ message: FriendInviteMessage) {
        guard valid else { return }
        received(PushEvent(id:message.hashKey,destination:.friends,title:message.fNick.isEmpty ? "好友申请":message.fNick,
                           body:message.reason.isEmpty ? "请求添加您为好友~":message.reason,muted:false,fromSelf:false))
    }
}
