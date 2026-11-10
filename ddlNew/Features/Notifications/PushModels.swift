import Foundation
import CoreFoundation

nonisolated struct PushIdentity: Equatable, Sendable {
    let userUID: String
    let tenantID: String
    let sessionID: UUID
    var cacheKey: String { "push.preferences." + Data("\(tenantID.utf8.count):\(tenantID)\(userUID)".utf8).base64EncodedString() }
}

nonisolated struct PushPreferences: Codable, Equatable, Sendable {
    var enabled = true
    var sound = true
    var vibration = true
    static func decode(_ value: [String: Any]) -> Self? {
        func flag(_ key: String) -> Bool? {
            if let v = value[key] as? NSNumber, [0,1].contains(v.intValue), v.doubleValue == Double(v.intValue) { return v.intValue == 1 }
            if let v = value[key] as? String, ["0","1"].contains(v) { return v == "1" }
            return nil
        }
        guard let enabled = flag("isNewMsgNotify"), let sound = flag("isVoiceNotice"), let vibration = flag("isShakeNotice") else { return nil }
        return Self(enabled: enabled, sound: sound, vibration: vibration)
    }
    static func saveAccepted(_ data: Any?) -> Bool {
        if let value = data as? NSNumber { return value.doubleValue == 1 }
        if let value = data as? String { return value == "1" || value.lowercased() == "true" }
        return false
    }
    var parameters: [String: Any] { ["isNewMsgNotify":enabled ? 1:0, "isVoiceNotice":sound ? 1:0,"isShakeNotice":vibration ? 1:0] }
}

nonisolated enum PushDestination: Equatable, Hashable, Sendable {
    case chat(id: String, group: Bool)
    case friends
    static func parse(_ info: [AnyHashable: Any]) -> Self? {
        guard let type = info["jumpType"] as? String else { return nil }
        if type == "friend" { return .friends }
        guard type == "chat", let id = info["sessionId"] as? String,
              !id.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty, id.count <= 512 else { return nil }
        let kind: Int?
        if let number = info["chatType"] as? NSNumber {
            guard CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue == Double(number.intValue) else { return nil }
            kind = number.intValue
        } else { kind = (info["chatType"] as? String).flatMap(Int.init) }
        guard let kind, [0,1].contains(kind) else { return nil }
        return .chat(id:id, group:kind == 1)
    }
    var info: [AnyHashable:Any] {
        switch self {
        case .friends: return ["jumpType":"friend"]
        case .chat(let id, let group): return ["jumpType":"chat","chatType":group ? 1:0,"sessionId":id]
        }
    }
}

nonisolated enum PushProcess { static let id = UUID() }

nonisolated struct PushPayload: Equatable, Sendable {
    let destination: PushDestination
    var userUID: String?
    var tenantID: String?
    var processID: UUID?
    var sessionID: UUID?
    init(destination: PushDestination, userUID: String? = nil, tenantID: String? = nil, processID: UUID? = nil, sessionID: UUID? = nil) {
        self.destination = destination; self.userUID = userUID; self.tenantID = tenantID
        self.processID = processID; self.sessionID = sessionID
    }
    init?(info: [AnyHashable:Any]) {
        guard let destination = PushDestination.parse(info) else { return nil }
        for key in ["recipientUID", "tenantID"] where info[key] != nil {
            guard let value = info[key] as? String, !value.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
                  value.count <= 512 else { return nil }
        }
        var process: UUID?, session: UUID?
        if info["localProcessID"] != nil || info["localSessionID"] != nil {
            guard let p=info["localProcessID"] as? String, let parsedProcess=UUID(uuidString:p),
                  let r=info["localSessionID"] as? String, let parsedSession=UUID(uuidString:r),
                  info["recipientUID"] != nil, info["tenantID"] != nil else { return nil }
            process=parsedProcess; session=parsedSession
        }
        self.init(destination:destination, userUID:info["recipientUID"] as? String, tenantID:info["tenantID"] as? String,
                  processID:process,sessionID:session)
    }
    func matches(_ owner: PushIdentity) -> Bool {
        (userUID == nil || userUID == owner.userUID) && (tenantID == nil || tenantID == owner.tenantID)
        && (processID != PushProcess.id || sessionID == owner.sessionID)
    }
    var info: [AnyHashable:Any] {
        var result = destination.info
        if let userUID { result["recipientUID"] = userUID }
        if let tenantID { result["tenantID"] = tenantID }
        if let processID { result["localProcessID"] = processID.uuidString }
        if let sessionID { result["localSessionID"] = sessionID.uuidString }
        return result
    }
}

nonisolated struct PushEvent: Equatable, Sendable {
    let id: String
    let destination: PushDestination
    let title: String
    let body: String
    let muted: Bool
    let fromSelf: Bool
}

nonisolated struct PushDeliveryPolicy {
    private var seen: Set<String> = []
    private var order: [String] = []
    private var invitations: [String:TimeInterval] = [:]
    mutating func reset() { seen.removeAll(); order.removeAll(); invitations.removeAll() }
    mutating func accept(_ event: PushEvent, preferences: PushPreferences, foreground: Bool, visible: PushDestination?, now: TimeInterval = Date.timeIntervalSinceReferenceDate) -> Bool {
        guard preferences.enabled, !event.muted, !event.fromSelf, !event.id.isEmpty,
              !event.title.isEmpty, !event.body.isEmpty, !(foreground && visible == event.destination) else { return false }
        // 好友hashKey只标识用户对，不能作为永久事件ID；仅合并短时间重复回调。
        if event.destination == .friends {
            invitations = invitations.filter { now - $0.value < 5 }
            guard invitations[event.id] == nil else { return false }
            invitations[event.id] = now; return true
        }
        let key = String(describing:event.destination) + ":" + event.id
        guard seen.insert(key).inserted else { return false }
        order.append(key)
        if order.count > 512 { seen.remove(order.removeFirst()) }
        return true
    }
}

nonisolated enum PushMessageSummary {
    static func mention(title: String, text: String, targets: [String], userUID: String) -> String {
        targets.contains(userUID) || targets.contains("-1") ? title + L10n.tr("@了你") : text
    }
    static func allowsGroupNotice(informStatus: Int?) -> Bool { informStatus == 1 }
}
