import Foundation
import Combine

/// 只由已认证会话激活，不能从用于离线展示的 currentUser 推导网络资格。
@MainActor final class AccountSettingsStore: ObservableObject {
    static let shared = AccountSettingsStore()
    @Published private(set) var current = AccountSettingsSnapshot(settings: nil)
    private var identity: Identity?
    private struct Identity: Equatable { let userUID: String; let tenantID: String; let sessionID: UUID }

    func activate(userUID: String, tenantID: String, sessionID: UUID, settings: UserSettings?) {
        identity = Identity(userUID: userUID, tenantID: tenantID, sessionID: sessionID)
        publish(settings)
    }
    func update(settings: UserSettings?, userUID: String, tenantID: String, sessionID: UUID) {
        guard matches(userUID: userUID, tenantID: tenantID, sessionID: sessionID) else { return }
        publish(settings)
    }
    func matches(userUID: String, tenantID: String, sessionID: UUID) -> Bool {
        identity == Identity(userUID: userUID, tenantID: tenantID, sessionID: sessionID)
    }
    func reset() { identity = nil; publish(nil) }
    private func publish(_ settings: UserSettings?) {
        let next = AccountSettingsSnapshot(settings: settings)
        if current != next { current = next }
    }
}
