//
//  SDKCallDelegate.swift
//  ddlNew
//
//  Created by taobo on 2026/10/20.
//

import Foundation
import NoaChatCore

/// 每次 AUTH 新建代理；已排队的旧代理事件在主线程投递时再次失效。
final class SDKCallDelegate: NSObject, NoaIMMediaCallDelegate {
    private let userUID: String
    @MainActor private var callback: ((CallSignal) -> Void)?
    @MainActor init(userUID: String, onSignal: @escaping (CallSignal) -> Void) { self.userUID = userUID; self.callback = onSignal }
    @MainActor func invalidate() { callback = nil }
    nonisolated private func send(_ signal: CallSignal) { Task { @MainActor [weak self] in self?.callback?(signal) } }
    nonisolated private func value(_ model: LIMMediaCallModel) -> CallRoomDescriptor? { SDKCallPayload.liveKit(model, localID: userUID) }

    nonisolated func imSdkMediaCallSingleInviteeReceiveRequest(with model: LIMMediaCallModel) { if let value = value(model), value.recipientID == userUID { send(.incoming(value)) } }
    nonisolated func imSdkMediaCallSingleInviteeAcceptRequest(with model: LIMMediaCallModel) { if let value = value(model) { send(.accepted(value)) } }
    nonisolated func imSdkMediaCallSingleInviterConfirmRoom(with model: LIMMediaCallModel) { if let value = value(model) { send(.confirmed(value)) } }
    nonisolated func imSdkMediaCallSingleDiscard(with model: LIMMediaCallModel) { if let value = value(model) { send(.ended(value)) } }
    nonisolated func imSdkMediaCallGroupRequest(with model: LIMMediaCallModel) {
        if let value = value(model), value.callerID != userUID, value.participants.contains(where: { $0.id == userUID }) { send(.incoming(value)) }
    }
    nonisolated func imSdkMediaCallGroupInvite(with model: LIMMediaCallModel) {
        guard let value = value(model) else { return }
        if value.operationIDs.contains(userUID) { send(.incoming(value)) }
        else { send(.members(value)) }
    }
    nonisolated func imSdkMediaCallGroupJoin(with model: LIMMediaCallModel) { if let value = value(model) { send(.members(value)) } }
    nonisolated func imSdkMediaCallGroupLeave(with model: LIMMediaCallModel) {
        guard var value = value(model) else { return }
        value.status = 5
        if value.operationIDs.contains(userUID) { send(.ended(value)) } else { send(.members(value)) }
    }
    nonisolated func imSdkMediaCallGroupDiscard(with model: LIMMediaCallModel) { if let value = value(model) { send(.ended(value)) } }
    nonisolated func imSdkMediaCallGroupParticipantAction(with model: LIMMediaCallModel) {
        let cached: LIMMediaCallGroupParticipantAction? = model.callGroupParticipantActionModel
        if let action = cached { send(.groupChanged(action.chat_id)) }
    }
    nonisolated func imSdkCallInviteeReceiveRequest(with message: IMChatMessage) {
        let value = SDKCallPayload.zego(message, localID: userUID)
        if !value.groupID.isEmpty { send(.groupChanged(value.groupID)) }
        guard value.callerID != userUID, value.groupID.isEmpty || value.operationIDs.contains(userUID) else { return }
        send(.incoming(value))
    }
    nonisolated func imSdkCallInviteeAcceptRequest(with message: IMChatMessage) { send(.accepted(SDKCallPayload.zego(message, localID: userUID))) }
    nonisolated func imSdkCallDiscard(with message: IMChatMessage) {
        let value = SDKCallPayload.zego(message, localID: userUID)
        send(.ended(value))
        if !value.groupID.isEmpty { send(.groupChanged(value.groupID)) }
    }
    nonisolated func imSdkCallGroupMemberStateChange(with message: IMChatMessage) {
        let value = SDKCallPayload.zego(message, localID: userUID)
        if value.status == 11 || ([3,4,5,7,8,12].contains(value.status) && value.operationIDs.contains(userUID)) { send(.ended(value)) }
        else { send(.members(value)) }
        send(.groupChanged(value.groupID))
    }
}
