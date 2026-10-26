//
//  SessionMaintenanceCoordinator.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import ObjectMapper

/// 首次 AUTH、回到前台、定时与节点切换共用同一串行刷新入口。
@MainActor
final class SessionMaintenanceCoordinator {
    static let shared = SessionMaintenanceCoordinator()
    private let client = SDKSessionMaintenanceClient()
    private var userUID: String?
    private var license: String?
    private lazy var engine = SessionMaintenanceEngine { [weak self] current in
        await self?.refresh(current: current)
    }
    private init() {}

    func start(userUID: String, lastLiceseId: String) {
        self.userUID = userUID
        license = lastLiceseId
        UserRoleAuthorityStore.shared.prepare(userUID: userUID, lastLiceseId: lastLiceseId)
        LoginSessionService.shared.conversations.setFileAssistantVisible(
            UserRoleAuthorityStore.shared.current?.allows("isShowFileAssistant") == true)
        engine.setAuthenticated(IMUserAuthenticationService.shared.isAuthenticated)
        engine.start(identity: "\(lastLiceseId):\(userUID)", requiresAuthentication: true)
    }

    func stop() {
        engine.stop()
        userUID = nil
        license = nil
        UserRoleAuthorityStore.shared.reset()
    }
    func setForegroundActive(_ active: Bool) { engine.setForegroundActive(active) }
    func setAuthenticated(_ value: Bool) { engine.setAuthenticated(value) }
    func refreshNow() { engine.refreshNow() }
    func refreshAfterNodeChange() { engine.refreshNow() }

    private func refresh(current: @escaping @MainActor () -> Bool) async {
        guard let license, let plan = OSSConnectionBootstrap.shared.current,
              plan.lastLiceseId == license, let nav = try? OSSNavigationStore.shared.load(),
              nav.lastLiceseId == license else { return }
        guard let uid = userUID else { return }
        let sessionID = LoginSessionService.shared.maintenanceSessionID
        let rejected: @MainActor (Int, String) -> Void = { code, message in
            guard let sessionID else { return }
            LoginSessionService.shared.handleMaintenanceRejection(code: code, message: message,
                userUID: uid, lastLiceseId: license, sessionID: sessionID)
        }
        // Host 与导航保存时间都参与校验，同一邀请码重新导航也不能接收旧结果。
        let valid: @MainActor () -> Bool = { [weak self] in
            guard current(), let self, self.license == license, self.userUID == uid,
                  OSSConnectionBootstrap.shared.current?.apiHost == plan.apiHost,
                  OSSConnectionBootstrap.shared.current?.lastLiceseId == license,
                  let latest = try? OSSNavigationStore.shared.load(), latest.savedAt == nav.savedAt,
                  latest.lastLiceseId == license else { return false }
            return IMUserAuthenticationService.shared.isAuthenticated
                    && UserSessionStore.shared.currentUser?.userUID == uid
        }
        guard valid() else { return }
        do {
            let json = try await client.profile(userUID: uid, onRejected: rejected)
            guard valid(), let bytes = json.data(using: .utf8),
                  let fields = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { return }
            try UserSessionStore.shared.updateProfile(fields, userUID: uid, lastLiceseId: license)
        } catch { if valid() { debugPrint("[会话维护] 用户资料刷新失败，保留原资料") } }
        guard valid() else { return }
        do {
            let json = try await client.roleAuthority(userUID: uid, onRejected: rejected)
            guard valid(), let role = Mapper<UserRoleAuthority>().map(JSONString: json) else { return }
            UserRoleAuthorityStore.shared.update(role, userUID: uid, lastLiceseId: license)
            LoginSessionService.shared.conversations.setFileAssistantVisible(role.allows("isShowFileAssistant"))
        } catch { if valid() { debugPrint("[会话维护] 角色权限刷新失败，保留原权限") } }
        if valid() { LoginSecurityCoordinator.shared.refreshIfNeeded() }
    }
}
