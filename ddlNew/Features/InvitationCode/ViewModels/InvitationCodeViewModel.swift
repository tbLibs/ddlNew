//
//  InvitationCodeViewModel.swift
//  ddlNew
//
//  Created by taobo on 2026/9/21.
//

import Foundation
import Combine

/// 邀请码页面的状态容器，后续校验、请求和跳转触发逻辑统一放在这里。
@MainActor
final class InvitationCodeViewModel: ObservableObject {
    
    /// 用户输入的邀请码。
    @Published var invitationCode = "10001" {
        didSet {
            guard invitationCode != oldValue else { return }
            // 输入变化后，旧邀请码的竞速结果不能继续显示或覆盖新状态。
            raceTask?.cancel()
            raceTask = nil
            raceWinner = nil
            navigationSnapshot = nil
            connectionPlan = nil
            systemConfig = nil
            IMConnectionCoordinator.shared.reset()
            OSSConnectionBootstrap.shared.clearCurrent()
            raceRunID = UUID()
            isRacing = false
            statusMessage = nil
        }
    }

    /// 正在导航或初始化 TCP/ECDH 和系统配置，避免重复点击。
    @Published private(set) var isRacing = false
    /// 展示导航、握手与系统配置进度或失败原因。
    @Published private(set) var statusMessage: String?
    /// 本次竞速的原始首胜结果；后续连接应使用已保存的 navigationSnapshot。
    @Published private(set) var raceWinner: OSSRaceWinner?
    /// 已持久化的最新导航状态，后续连接层直接读取唯一的导航缓存。
    @Published private(set) var navigationSnapshot: OSSNavigationSnapshot?
    /// 已选的 HTTP API Host 与 TCP 候选；实际就绪状态由连接协调器管理。
    @Published private(set) var connectionPlan: OSSConnectionPlan?
    /// 当前邀请码的系统配置；获取失败时不会误认为登录已就绪。
    @Published private(set) var systemConfig: SystemConfigRecord?

    /// 保留当前竞速任务，以便邀请码变更时取消旧请求。
    private var raceTask: Task<Void, Never>?
    /// 标识最新一次点击，阻止取消中的旧任务覆盖新状态。
    private var raceRunID = UUID()
    
    /// 点击连接俱乐部
    func clickClub() {
        // 本次请求始终使用当前输入；持久化的 lastLiceseId 仅在配置获取成功后更新。
        let lastLiceseId = invitationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lastLiceseId.isEmpty else {
            statusMessage = "请输入邀请码"
            return
        }
        let credentials = OSSAuthCredentials(
            signingKeyID: DirectDecodeKeyId,
            signingKeySecret: DirectDecodeKeySecret
        )

        raceTask?.cancel()
        raceWinner = nil
        navigationSnapshot = nil
        connectionPlan = nil
        systemConfig = nil
        IMConnectionCoordinator.shared.reset()
        OSSConnectionBootstrap.shared.clearCurrent()
        let runID = UUID()
        raceRunID = runID
        isRacing = true
        statusMessage = "正在竞速导航节点…"
        raceTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.raceRunID == runID {
                    self.isRacing = false
                    self.raceTask = nil
                }
            }
            do {
                // 旧项目在 OSS Auth 前获取出口公网 IP；失败时沿用空字符串兜底。
                let clientIP = await PublicIPResolver.resolve()
                try Task<Never, Never>.checkCancellation()
                let winner = try await OSSNodeRaceCoordinator.race(lastLiceseId: lastLiceseId, credentials: credentials, clientIP: clientIP)
                try Task<Never, Never>.checkCancellation()
                let snapshot = try OSSNavigationStore.shared.save(winner, lastLiceseId: lastLiceseId)
                guard !Task.isCancelled, self.raceRunID == runID else { return }
                let plan = try OSSConnectionBootstrap.shared.prepare(
                    requireFresh: false
                )
                raceWinner = winner
                navigationSnapshot = snapshot
                connectionPlan = plan
                debugPrint("[OSS竞速] 获胜来源：\(winner.source.rawValue)，地址：\(winner.node.urlString)")
                debugPrint("[OSS连接] HTTP：\(plan.apiHost.absoluteString)，TCP 候选：\(plan.tcpCandidates.count) 个")

                statusMessage = "正在建立 TCP/ECDH 连接，成功后获取系统配置…"
                do {
                    let configuration = try await IMConnectionCoordinator.shared.connectForLogin(plan: plan)
                    try Task<Never, Never>.checkCancellation()
                    guard self.raceRunID == runID else { return }
                    systemConfig = configuration
                    debugPrint("[系统配置] 获取成功：登录方式=\(configuration.loginMethod)，验证码渠道=\(configuration.captchaChannel)")
                    // 正式 ECDH 与最新系统配置都成功后才进入登录页。
                    RouterTool.shared.showAppPage = .login
                    return
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled, self.raceRunID == runID else { return }
                    if case SystemConfigCryptoError.unavailableOnSimulator = error {
                        statusMessage = "导航已保存；系统配置签名需要真机运行"
                    } else {
                        statusMessage = "TCP/ECDH 或系统配置初始化失败，请重试"
                    }
                    debugPrint("[IM初始化] 连接或系统配置失败：\(error)")
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, self.raceRunID == runID else { return }
                statusMessage = "导航获取或节点准备失败，请重试"
                debugPrint("[OSS导航] 获取或节点准备失败：\(error)")
            }
        }
    }
    
}
