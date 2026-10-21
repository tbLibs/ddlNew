//
//  CallClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/20.
//

import Foundation

enum CallAction { case create, receive, accept, confirm, invite, join, end, groupInfo, token, confirmJoin, heartbeat }

@MainActor protocol CallClient: AnyObject {
    func observe(userUID: String, onSignal: @escaping @MainActor (CallSignal) -> Void)
    func stopObserving()
    func canOffer(context: ChatContext) -> Bool
    func validateTarget(context: ChatContext) async throws
    func members(context: ChatContext) async throws -> [CallParticipant]
    func participant(id: String, localID: String) -> CallParticipant
    func perform(_ action: CallAction, descriptor: CallRoomDescriptor, context: ChatContext, ids: [String]) async throws -> CallRoomDescriptor
}

@MainActor protocol CallMediaEngine: AnyObject {
    var onConnected: (() -> Void)? { get set }
    var onParticipants: (([CallParticipant]) -> Void)? { get set }
    var onFailure: ((String) -> Void)? { get set }
    var onReconnecting: ((Bool) -> Void)? { get set }
    var onTokenExpired: (() -> Void)? { get set }
    func connect(descriptor: CallRoomDescriptor, session: CallSession, configuration: CallConfiguration)
    func startPublishing()
    func disconnect()
    func microphone(_ enabled: Bool, completion: @escaping (Bool) -> Void)
    func camera(_ enabled: Bool, completion: @escaping (Bool) -> Void)
    func speaker(_ enabled: Bool) throws
    func switchCamera(completion: @escaping (Bool) -> Void)
    func renewToken(_ token: String)
}
