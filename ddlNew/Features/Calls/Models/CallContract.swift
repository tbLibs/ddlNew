//
//  CallContract.swift
//  ddlNew
//
//  Created by taobo on 2026/10/20.
//

import Foundation

enum CallKind: Int, Sendable { case audio = 1, video = 2 }
enum CallProvider: Int, Sendable { case liveKit = 0, zego = 1 }
enum CallPhase: Sendable { case outgoing, incoming, connecting, connected, ending }

/// 旧端实际调用传数组；SDK 头文件遗留的 JSON 字符串注释不作为请求合同。
enum CallRequestPayload {
    nonisolated static func create(provider: CallProvider, groupID: String?, kind: CallKind, ids: [String]) -> [String: Any] {
        if provider == .liveKit {
            var result: [String: Any] = ["mode": kind == .audio ? 1 : 0]
            if let groupID { result["chat_id"] = groupID; result["to_id"] = ids }
            else { result["to_id"] = ids.first ?? "" }
            return result
        }
        var result: [String: Any] = ["callType": kind == .audio ? "Voice" : "Video", "chatType": groupID == nil ? "SINGLE_CHAT" : "GROUP_CHAT", "friendIds": ids]
        if let groupID { result["groupId"] = groupID }
        return result
    }
    nonisolated static func invite(provider: CallProvider, roomID: String, ids: [String]) -> [String: Any] {
        provider == .liveKit ? ["hash": roomID, "user_id": ids] : ["callId": roomID, "friendIds": ids]
    }
}

enum CallPolicy {
    nonisolated static func groupCanCall(active: Bool, prohibited: Bool, role: Int) -> Bool {
        active && (!prohibited || role == 1 || role == 2)
    }
    nonisolated static func endReason(incoming: Bool, connected: Bool) -> String {
        connected ? "" : incoming ? "refused" : "cancel"
    }
}

enum CallError: LocalizedError {
    case unavailable(String)
    case server(code: Int, message: String)
    nonisolated var errorDescription: String? {
        switch self {
        case .unavailable(let message): return message
        case .server(let code, let message):
            // 与 xgd NoaNetResultCode.plist 的通话错误映射一致。
            switch code {
            case 900017: return "用户已经注销"
            case 900018: return "用户已经被拉黑"
            case 900019: return "你已经被拉黑"
            case 910001: return "对方正在通话中"
            case 910002: return "你已经在通话中了"
            case 910003: return "通话记录不存在"
            case 910004: return "用户不在线"
            case 910005: return "通话状态错误"
            case 910006: return "通话token构建错误"
            case 910007: return "邀请的用户不符合条件"
            case 910008: return "通话已结束"
            default:
                let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? "通话请求失败，请稍后重试" : text
            }
        }
    }
}
