//
//  SDKCallClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/20.
//

import Foundation
import NoaChatCore

@MainActor final class SDKCallClient: CallClient {
    private var observer: SDKCallDelegate?
    private let validSession: (ChatContext) -> Bool
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }

    init(validSession: @escaping (ChatContext) -> Bool) { self.validSession = validSession }

    func observe(userUID: String, onSignal: @escaping @MainActor (CallSignal) -> Void) {
        stopObserving()
        let observer = SDKCallDelegate(userUID: userUID, onSignal: onSignal)
        self.observer = observer
        sdk.addMediaCallDelegate(observer)
    }
    func stopObserving() {
        if let observer { observer.invalidate(); sdk.removeMediaCallDelegate(observer) }
        observer = nil
    }

    func participant(id: String, localID: String) -> CallParticipant {
        if id == localID, let user = UserSessionStore.shared.currentUser {
            return CallParticipant(id: id, name: user.nickname, avatar: user.avatar, isLocal: true, isConnected: false, cameraEnabled: false, microphoneEnabled: true)
        }
        let friend: LingIMFriendModel? = sdk.toolCheckMyFriend(with: id)
        return CallParticipant(id: id, name: friend.map { $0.showName.isEmpty ? id : $0.showName } ?? id, avatar: friend?.avatar ?? "", isLocal: false, isConnected: false, cameraEnabled: false, microphoneEnabled: true)
    }

    func canOffer(context: ChatContext) -> Bool {
        guard validSession(context) else { return false }
        if context.route.kind == .group {
            let cached: LingIMGroupModel? = sdk.toolCheckMyGroup(with: context.route.id)
            guard let group = cached else { return false }
            return CallPolicy.groupCanCall(active: group.groupStatus == 1 && group.leaveGroupStatus == 0, prohibited: group.isNetCall, role: group.userGroupRole)
        }
        guard context.route.kind == .single, let friend: LingIMFriendModel = sdk.toolCheckMyFriend(with: context.route.id) else { return false }
        return friend.disableStatus != 4 && context.route.id != "100002" && context.route.id != context.userUID
    }

    func validateTarget(context: ChatContext) async throws {
        try validate(context)
        if context.route.kind == .single {
            guard context.route.id != context.userUID, context.route.id != "100002", let friend: LingIMFriendModel = sdk.toolCheckMyFriend(with: context.route.id), friend.disableStatus != 4 else { throw CallError.unavailable("当前用户无法发起通话") }
        } else if context.route.kind == .group {
            let data = try await group(context: context)
            guard CallPolicy.groupCanCall(active: SDKCallPayload.integer(data["groupStatus"]) == 1 && SDKCallPayload.flag(data["userInGroup"]), prohibited: SDKCallPayload.flag(data["isNetCall"]), role: SDKCallPayload.integer(data["userGroupRole"])) else { throw CallError.unavailable("当前群不允许发起通话") }
        } else { throw CallError.unavailable("此会话不支持通话") }
    }

    func members(context: ChatContext) async throws -> [CallParticipant] {
        try await validateTarget(context: context)
        var result: [String: CallParticipant] = [:]
        var page = 1
        while true {
            let currentPage = page
            let data = try await request(context: context) { success, failure in
                self.sdk.getGroupMemberList(with: NSMutableDictionary(dictionary: ["groupId": context.route.id, "userUid": context.userUID, "pageSize": 100, "pageNumber": currentPage, "pageStart": (currentPage - 1) * 100]), onSuccess: success, onFailure: failure)
            }
            let rows = try ChatGroupMemberPage.rows(from: data)
            let before = result.count
            for row in rows {
                let id = SDKCallPayload.string(row["userUid"])
                guard !id.isEmpty, id != context.userUID, SDKCallPayload.integer(row["disableStatus"]) != 4, SDKCallPayload.integer(row["role"]) != 3 else { continue }
                let name = ["remarks", "nicknameInGroup", "userNickname", "nickname"].map { SDKCallPayload.string(row[$0]) }.first { !$0.isEmpty } ?? id
                result[id] = CallParticipant(id: id, name: name, avatar: SDKCallPayload.string(row["userAvatar"] ?? row["avatar"]), isLocal: false, isConnected: false, cameraEnabled: false, microphoneEnabled: true)
            }
            if rows.count < 100 { break }
            guard page < 1000 else { throw CallError.unavailable("群成员过多，请稍后重试") }
            // 满页但全部被过滤不表示分页结束；按真实页数继续。
            if result.count == before && rows.isEmpty { break }
            page += 1
        }
        try validate(context)
        return result.values.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func perform(_ action: CallAction, descriptor: CallRoomDescriptor, context: ChatContext, ids: [String] = []) async throws -> CallRoomDescriptor {
        var params: [String: Any] = [descriptor.provider == .liveKit ? "hash" : "callId": descriptor.id]
        let isGroup = !descriptor.groupID.isEmpty
        switch action {
        case .create: params = CallRequestPayload.create(provider: descriptor.provider, groupID: isGroup ? descriptor.groupID : nil, kind: descriptor.kind, ids: ids)
        case .invite: params = CallRequestPayload.invite(provider: descriptor.provider, roomID: descriptor.id, ids: ids)
        case .end: if descriptor.provider == .liveKit { params["reason"] = descriptor.reason }
        case .groupInfo: params = [descriptor.provider == .liveKit ? "chat_id" : "groupId": context.route.id]
        default: break
        }
        let arguments = NSMutableDictionary(dictionary: params)
        let data = try await request(context: context) { success, failure in
            if descriptor.provider == .liveKit {
                switch action {
                case .create: if isGroup { self.sdk.imSdkCallGroupRequest(with: arguments, onSuccess: success, onFailure: failure) } else { self.sdk.imSdkCallRequestCall(with: arguments, onSuccess: success, onFailure: failure) }
                case .receive: self.sdk.imSdkCallReceiveCall(with: arguments, onSuccess: success, onFailure: failure)
                case .accept: if isGroup { self.sdk.imSdkCallGroupAccept(with: arguments, onSuccess: success, onFailure: failure) } else { self.sdk.imSdkCallAcceptCall(with: arguments, onSuccess: success, onFailure: failure) }
                case .confirm: self.sdk.imSdkCallConfirmCall(with: arguments, onSuccess: success, onFailure: failure)
                case .invite: self.sdk.imSdkCallGroupInvite(with: arguments, onSuccess: success, onFailure: failure)
                case .join: self.sdk.imSdkCallGroupJoin(with: arguments, onSuccess: success, onFailure: failure)
                case .end: if isGroup { self.sdk.imSdkCallGroupDiscard(with: arguments, onSuccess: success, onFailure: failure) } else { self.sdk.imSdkCallDiscardCall(with: arguments, onSuccess: success, onFailure: failure) }
                case .groupInfo: self.sdk.imSdkCallGroupState(with: arguments, onSuccess: success, onFailure: failure)
                default: success([:], nil)
                }
            } else {
                switch action {
                case .create: self.sdk.imSdkUserCreateCall(with: arguments, onSuccess: success, onFailure: failure)
                case .accept: self.sdk.imSdkUserAcceptCall(with: arguments, onSuccess: success, onFailure: failure)
                case .invite: self.sdk.imSdkUserInviteToCall(with: arguments, onSuccess: success, onFailure: failure)
                case .join: self.sdk.imSdkUserJoinCall(with: arguments, onSuccess: success, onFailure: failure)
                case .end:
                    if descriptor.reason == "cancel" { self.sdk.imSdkUserCancelCall(with: arguments, onSuccess: success, onFailure: failure) }
                    else if descriptor.reason == "refused" { self.sdk.imSdkUserRejectCall(with: arguments, onSuccess: success, onFailure: failure) }
                    else { self.sdk.imSdkUserHangUpCall(with: arguments, onSuccess: success, onFailure: failure) }
                case .groupInfo: self.sdk.imSdkUserGetGroupCallInfo(with: arguments, onSuccess: success, onFailure: failure)
                case .token: self.sdk.imSdkUserGetCallInfoToken(with: arguments, onSuccess: success, onFailure: failure)
                case .confirmJoin: self.sdk.imSdkUserConfirmJoinCall(with: arguments, onSuccess: success, onFailure: failure)
                case .heartbeat: self.sdk.userHeartbeatCall(with: arguments, onSuccess: success, onFailure: failure)
                default: success([:], nil)
                }
            }
        }
        let result = SDKCallPayload.response(data, original: descriptor, localID: context.userUID)
        if action == .create && result.id.isEmpty { throw CallError.unavailable("通话响应无效，请重试") }
        return result
    }

    private func group(context: ChatContext) async throws -> [String: Any] {
        try await request(context: context) { success, failure in self.sdk.getGroupInfo(with: ["groupId": context.route.id, "userUid": context.userUID], onSuccess: success, onFailure: failure) }
    }
    private func validate(_ context: ChatContext) throws { guard validSession(context), !Task.isCancelled else { throw CancellationError() } }

    /// SDK 不可取消的运输回执转为有界等待，解析前后核对认证身份。
    private func request(context: ChatContext, start: @escaping ( @escaping LingIMSuccessCallback, @escaping LingIMFailureCallback) -> Void) async throws -> [String: Any] {
        try validate(context)
        // 运输层保留原20秒超时/取消；业务拒绝作为带错误码的结果传递，避免降为 invalidResponse。
        let waiter = SDKLoginRequestWaiter<Result<String, CallError>>()
        let response = try await waiter.run {
            start({ value, _ in
                let data = try? JSONSerialization.data(withJSONObject: value ?? [:], options: [.fragmentsAllowed])
                let text = data.flatMap { String(data: $0, encoding: .utf8) }
                Task { @MainActor in
                    if let text { waiter.finish(.success(.success(text))) }
                    else { waiter.finish(.failure(.invalidResponse)) }
                }
            }, { code, message, _ in
                Task { @MainActor in waiter.finish(.success(.failure(.server(code: code, message: message ?? "")))) }
            })
        }
        try validate(context)
        let json = try response.get()
        guard let data = json.data(using: .utf8) else { throw CallError.unavailable("通话响应无效，请重试") }
        let value = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        if value is NSNull { return [:] }
        if let result = value as? [String: Any] { return result }
        if let boolean = value as? Bool, boolean { return [:] }
        throw CallError.unavailable("通话响应无效，请重试")
    }
}
