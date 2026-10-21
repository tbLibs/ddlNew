import Foundation

/// 只从已经落库的终态取显示字段，不读取房间凭据，也不生成第二份通话消息。
enum ChatCallSummary {
    nonisolated static func liveKit(type: Int, content: String, userUID: String) -> String {
        guard let data = content.data(using: .utf8),
              let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }
        func string(_ key: String) -> String { body[key] as? String ?? (body[key] as? NSNumber)?.stringValue ?? "" }
        let kind = string("mode") == "0" ? "视频通话" : "语音通话"
        if type == 103 {
            switch string("action") {
            case "new": return kind
            case "discard": return kind + "已经结束"
            default: return ""
            }
        }
        guard type == 101, string("state") == "discard" else { return "" }
        return single(reason: string("discard_reason"), duration: Int(string("duration")) ?? 0,
                      outgoing: string("from_id") == userUID)
    }

    nonisolated static func zego(chatType: Int, kind: Int, status: Int, duration: Int, outgoing: Bool) -> String {
        if chatType == 2 {
            let name = kind == 2 ? "视频通话" : "语音通话"
            return status == 1 ? name : status == 11 ? name + "已经结束" : ""
        }
        guard chatType == 1 else { return "" }
        let reason: String
        switch status {
        case 2: reason = "cancel"
        case 3: reason = "missed"
        case 4: reason = "refused"
        case 5: reason = ""
        case 7: reason = "disconnect"
        case 8: reason = "accept"
        case 12: return "超时未应答"
        default: return ""
        }
        return single(reason: reason, duration: duration, outgoing: outgoing)
    }

    nonisolated private static func single(reason: String, duration: Int, outgoing: Bool) -> String {
        switch reason {
        case "cancel": return outgoing ? "已取消" : "对方已取消"
        case "missed": return outgoing ? "对方无应答" : "超时未应答"
        case "refused": return outgoing ? "对方已拒绝" : "已拒绝"
        case "accept": return outgoing ? "" : "已在其他设备接听"
        case "", "disconnect":
            let seconds = max(0, duration)
            let time = String(format: "%02d:%02d", seconds / 60, seconds % 60)
            let text = reason.isEmpty ? "通话结束" : "通话中断"
            return outgoing ? time + " " + text : text + " " + time
        default: return ""
        }
    }
}
