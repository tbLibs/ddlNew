//
//  SDKCallPayload.swift
//  ddlNew
//
//  Created by taobo on 2026/10/20.
//

import Foundation
import NoaChatCore

/// 在 SDK 边界形成纯值快照，回调离开后不继续持有可变 Protobuf/Objective-C 对象。
enum SDKCallPayload {
    nonisolated static func string(_ value: Any?) -> String { value as? String ?? (value as? NSNumber)?.stringValue ?? "" }
    nonisolated static func integer(_ value: Any?) -> Int { Int(string(value)) ?? 0 }
    nonisolated static func flag(_ value: Any?) -> Bool { ["1", "true"].contains(string(value).lowercased()) }

    nonisolated static func response(_ values: [String: Any], original: CallRoomDescriptor, localID: String) -> CallRoomDescriptor {
        var result = original
        if original.provider == .liveKit {
            let hash = string(values["hash"] ?? values["hashKey"])
            if !hash.isEmpty { result.id = hash }
            if let mode = values["mode"] { result.kind = integer(mode) == 0 ? .video : .audio }
            let group = string(values["chat_id"])
            if !group.isEmpty { result.groupID = group }
            let connection = values["connection"] as? [String: Any] ?? [:]
            if !string(connection["endpoint"]).isEmpty { result.endpoint = string(connection["endpoint"]) }
            if !string(connection["room"]).isEmpty { result.roomName = string(connection["room"]) }
            if !string(connection["token"]).isEmpty { result.token = string(connection["token"]) }
            if let participants = values["participants"] as? [[String: Any]] {
                result.participants = participants.compactMap { row in
                    let id = string(row["userUid"] ?? row["user_id"])
                    guard !id.isEmpty else { return nil }
                    let connected = integer(row["status"]) == 1
                    return CallParticipant(id: id, name: id, avatar: "", isLocal: id == localID, isConnected: connected, cameraEnabled: false, microphoneEnabled: true, stateText: connected ? "已加入" : "呼叫中")
                }
            } else if let participants = values["participants"] as? [String] {
                // 群当前房间查询返回 UID 数组，创建/加入返回带 status 的成员对象。
                result.participants = participants.filter { !$0.isEmpty }.map { CallParticipant(id: $0, name: $0, avatar: "", isLocal: $0 == localID, isConnected: false, cameraEnabled: false, microphoneEnabled: true) }
            }
        } else {
            if !string(values["callId"]).isEmpty { result.id = string(values["callId"]) }
            if !string(values["roomId"]).isEmpty { result.roomName = string(values["roomId"]) }
            if !string(values["token"]).isEmpty { result.token = string(values["token"]) }
            if let type = values["callType"] { result.kind = integer(type) == 2 || string(type) == "Video" ? .video : .audio }
            if let users = values["receiveUserInfo"] as? [[String: Any]] {
                result.participants = users.compactMap { row in
                    let id = string(row["userUid"])
                    guard !id.isEmpty else { return nil }
                    let name = string(row["nickname"])
                    return CallParticipant(id: id, name: name.isEmpty ? id : name, avatar: string(row["avatar"]), isLocal: id == localID, isConnected: false, cameraEnabled: false, microphoneEnabled: true)
                }
            }
        }
        return result
    }

    nonisolated static func liveKit(_ model: LIMMediaCallModel, localID: String) -> CallRoomDescriptor? {
        if let single = model.callSingleModel {
            let connection: LIMMediaCallRoomInfoModel? = single.connection
            return CallRoomDescriptor(provider: .liveKit, id: single.hashKey, kind: single.mode == 0 ? .video : .audio, callerID: single.from_id, recipientID: single.to_id, roomName: connection?.room ?? "", endpoint: connection?.endpoint ?? "", token: connection?.token ?? "", reason: single.discard_reason)
        }
        if let group = model.callGroupModel {
            let connection: LIMMediaCallRoomInfoModel? = group.connection
            let participants = group.participants.map { row in CallParticipant(id: row.userUid, name: row.userUid, avatar: "", isLocal: row.userUid == localID, isConnected: row.status == 1, cameraEnabled: false, microphoneEnabled: true, stateText: row.status == 1 ? "已加入" : "呼叫中") }
            return CallRoomDescriptor(provider: .liveKit, id: group.hashKey, groupID: group.chat_id, kind: group.mode == 0 ? .video : .audio, callerID: (group.args as? [String])?.first ?? "", roomName: connection?.room ?? "", endpoint: connection?.endpoint ?? "", token: connection?.token ?? "", participants: participants, operationIDs: group.args as? [String] ?? [], reason: group.reason)
        }
        return nil
    }

    nonisolated static func zego(_ message: IMChatMessage, localID: String) -> CallRoomDescriptor {
        guard let call = message.netCallMessage else { return CallRoomDescriptor(provider: .zego, id: "", kind: .audio) }
        let group = call.chatType == 2
        return CallRoomDescriptor(provider: .zego, id: call.callId, groupID: group ? message.to : "", kind: call.callType == 2 ? .video : .audio, callerID: call.roomCreateUser, recipientID: group ? "" : (message.from == localID ? message.to : localID), roomName: call.roomId, participants: (call.roomUsersArray as? [String] ?? []).map { CallParticipant(id: $0, name: $0, avatar: "", isLocal: $0 == localID, isConnected: [6, 10].contains(Int(call.status)) && (call.operationUsersArray as? [String] ?? []).contains($0), cameraEnabled: false, microphoneEnabled: true, stateText: [6, 10].contains(Int(call.status)) && (call.operationUsersArray as? [String] ?? []).contains($0) ? "已加入" : "呼叫中") }, operationIDs: call.operationUsersArray as? [String] ?? [], status: Int(call.status))
    }
}
