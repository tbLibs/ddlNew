//
//  AppStartupCoordinator.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

/// 本地入口决定是否恢复，缓存启动等待连接就绪后才结束启动等待页。
@MainActor
enum AppStartupCoordinator {
    /// 先恢复真实连接，再恢复已保存用户；AUTH 成功直达主页，否则显示登录或邀请码页。
    static func restoreLocalEntry() async throws -> ShowAppPageType {
        OSSConnectionBootstrap.shared.clearCurrent()
        if let lastLiceseId = OSSNavigationStore.shared.lastUsableLiceseId() {
            restoreConnectionPlan(lastLiceseId: lastLiceseId)
            IMConnectionCoordinator.shared.startCachedReconnect()
            return try await restoreUserEntry()
        }

        // 没有入口就显示邀请码页，不从历史缓存推断，避免撤销用户的更换俱乐部操作。
        debugPrint("[启动恢复] 没有上次可用入口，显示邀请码页")
        return .invitationCode
    }

    /// 启动期间暂时断网不等于退出登录；保留凭据，重新连接并退避重试认证。
    private static func restoreUserEntry() async throws -> ShowAppPageType {
        var attempt = 0
        while true {
            try Task<Never, Never>.checkCancellation()
            try await IMConnectionCoordinator.shared.waitForLoginReadiness()
            do {
                let restored = try await LoginSessionService.shared.restoreCachedSession()
                return restored ? .tabbar : .login
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if (error as? UserSessionError)?.invalidatesCachedSession == true {
                    debugPrint("[启动会话] 缓存身份已失效，请重新登录")
                    return .login
                }
                debugPrint("[启动会话] 暂未恢复成功，保留凭据重试：\(error)")
                let delay = UInt64(1 << min(attempt, 4))
                attempt += 1
                try await Task<Never, Never>.sleep(nanoseconds: delay * 1_000_000_000)
            }
        }
    }

    private static func restoreConnectionPlan(lastLiceseId: String) {
        do {
            let plan = try OSSConnectionBootstrap.shared.prepare(requireFresh: false)
            let hasConfiguration = SystemConfigStore.shared.load(apiHost: plan.apiHost) != nil
            debugPrint("[启动恢复] 邀请码：\(lastLiceseId)，TCP 候选：\(plan.tcpCandidates.count) 个，配置缓存：\(hasConfiguration)")
        } catch {
            // 缓存不可用不等于入口丢失：由后台恢复重新导航，等待页继续显示。
            OSSConnectionBootstrap.shared.clearCurrent()
            debugPrint("[启动恢复] 入口已保存，导航暂不可恢复：\(error)")
        }
    }
}
