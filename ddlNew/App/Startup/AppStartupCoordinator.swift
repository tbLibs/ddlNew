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
    /// 先恢复邀请码连接，再用成对缓存进行真实用户 AUTH，不依赖演示账号状态。
    static func restoreLocalEntry() async throws -> ShowAppPageType {
        OSSConnectionBootstrap.shared.clearCurrent()
        if let lastLiceseId = OSSNavigationStore.shared.lastUsableLiceseId() {
            restoreConnectionPlan(lastLiceseId: lastLiceseId)
            IMConnectionCoordinator.shared.startCachedReconnect()
            // 缓存仅用于恢复节点，必须完成正式握手和配置刷新后才显示登录页。
            do {
                try await IMConnectionCoordinator.shared.waitForLoginReadiness()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // 停止后台恢复，保留上次邀请码，允许用户从入口重新连接。
                IMConnectionCoordinator.shared.reset()
                OSSConnectionBootstrap.shared.clearCurrent()
                debugPrint("[启动恢复] 连接失败，返回邀请码页：\(error)")
                return .invitationCode
            }
            do {
                let restored = try await LoginSessionService.shared.restoreCachedSession(lastLiceseId: lastLiceseId)
                try Task<Never, Never>.checkCancellation()
                return restored ? .tabbar : .login
            } catch is CancellationError {
                LoginSessionService.shared.cancelStartupRestoration()
                throw CancellationError()
            } catch {
                // 连接已就绪但用户认证失败时允许重新登录，不把账号失败当作邀请码失败。
                debugPrint("[启动恢复] 未能恢复用户会话，返回登录页")
                return .login
            }
        }

        // 没有入口就显示邀请码页，不从历史缓存推断，避免撤销用户的更换俱乐部操作。
        debugPrint("[启动恢复] 没有上次可用入口，显示邀请码页")
        return .invitationCode
    }

    private static func restoreConnectionPlan(lastLiceseId: String) {
        do {
            let plan = try OSSConnectionBootstrap.shared.prepare(requireFresh: false)
            let hasConfiguration = SystemConfigStore.shared.load(apiHost: plan.apiHost, lastLiceseId: plan.lastLiceseId) != nil
            debugPrint("[启动恢复] 邀请码：\(lastLiceseId)，TCP 候选：\(plan.tcpCandidates.count) 个，配置缓存：\(hasConfiguration)")
        } catch {
            // 缓存不可用不等于入口丢失：由后台恢复重新导航，等待页继续显示。
            OSSConnectionBootstrap.shared.clearCurrent()
            debugPrint("[启动恢复] 入口已保存，导航暂不可恢复：\(error)")
        }
    }
}
