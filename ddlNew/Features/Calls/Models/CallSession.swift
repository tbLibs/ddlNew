//
//  CallSession.swift
//  ddlNew
//
//  Created by taobo on 2026/10/20.
//

import Foundation

struct CallParticipant: Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var avatar: String
    var isLocal: Bool
    var isConnected: Bool
    var cameraEnabled: Bool
    var microphoneEnabled: Bool
    var stateText: String = "呼叫中"
}

struct CallSession: Identifiable, Equatable, Sendable {
    let id: UUID
    var context: ChatContext
    var kind: CallKind
    var phase: CallPhase
    var title: String
    var isIncoming: Bool
    var participants: [CallParticipant]
    var connectedAt: Date?
    var microphoneEnabled: Bool
    var cameraEnabled: Bool
    var speakerEnabled: Bool
    var callerID: String = ""
}

struct CallSelectionRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let context: ChatContext
    let kind: CallKind
    let members: [CallParticipant]
    let selectedIDs: Set<String>
    let isAdditionalInvite: Bool
}

struct CallGroupRoom: Identifiable, Equatable, Sendable {
    let id: String
    var roomID: String
    var kind: CallKind
    var participants: [CallParticipant]
    var descriptor: CallRoomDescriptor
}

/// 仅存在于当前认证会话内，不编码、不记录房间 token。
struct CallRoomDescriptor: Equatable, Sendable {
    var provider: CallProvider
    var id: String
    var groupID: String = ""
    var kind: CallKind
    var callerID: String = ""
    var recipientID: String = ""
    var roomName: String = ""
    var endpoint: String = ""
    var token: String = ""
    var participants: [CallParticipant] = []
    var operationIDs: [String] = []
    var reason: String = ""
    var status: Int = 0
}

enum CallSignal: Sendable {
    case incoming(CallRoomDescriptor)
    case accepted(CallRoomDescriptor)
    case confirmed(CallRoomDescriptor)
    case ended(CallRoomDescriptor)
    case members(CallRoomDescriptor)
    case groupChanged(String)
}
