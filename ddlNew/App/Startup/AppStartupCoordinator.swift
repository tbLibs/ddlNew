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
    /// 当前还没有真实账号会话，只恢复邀请码或登录页，不恢复演示账号的登录状态。
    static func restoreLocalEntry() async throws -> ShowAppPageType {
        OSSConnectionBootstrap.shared.clearCurrent()
        if let lastLiceseId = OSSNavigationStore.shared.lastUsableLiceseId() {
            restoreConnectionPlan(lastLiceseId: lastLiceseId)
            IMConnectionCoordinator.shared.startCachedReconnect()
            // 缓存仅用于恢复节点，必须完成正式握手和配置刷新后才显示登录页。
            try await IMConnectionCoordinator.shared.waitForLoginReadiness()
            return .login
        }

        // 没有入口就显示邀请码页，不从历史缓存推断，避免撤销用户的更换俱乐部操作。
        debugPrint("[启动恢复] 没有上次可用入口，显示邀请码页")
        return .invitationCode
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
