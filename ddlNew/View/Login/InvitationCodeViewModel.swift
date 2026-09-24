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
            isRacing = false
            statusMessage = nil
        }
    }

    /// 正在获取公网 IP 并执行五路 OSS Auth 竞速，避免重复点击。
    @Published private(set) var isRacing = false
    /// 展示当前进度或失败原因，不代表后续 IM 连接已完成。
    @Published private(set) var statusMessage: String?
    /// 首个通过解密和端点校验的导航结果，供下一阶段连接使用。
    @Published private(set) var raceWinner: OSSRaceWinner?

    /// 保留当前竞速任务，以便邀请码变更时取消旧请求。
    private var raceTask: Task<Void, Never>?
    
    /// 点击连接俱乐部
    func clickClub() {
        let appID = invitationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appID.isEmpty else {
            statusMessage = "请输入邀请码"
            return
        }
        let credentials = OSSAuthCredentials(
            signingKeyID: DirectDecodeKeyId,
            signingKeySecret: DirectDecodeKeySecret
        )

        raceTask?.cancel()
        raceWinner = nil
        isRacing = true
        statusMessage = "正在竞速导航节点…"
        raceTask = Task { [weak self] in
            guard let self else { return }
            do {
                // 旧项目在 OSS Auth 前获取出口公网 IP；失败时沿用空字符串兜底。
                let clientIP = await PublicIPResolver.resolve()
                try Task<Never, Never>.checkCancellation()
                let winner = try await OSSNodeRaceCoordinator.race(appID: appID, credentials: credentials, clientIP: clientIP)
                guard !Task.isCancelled else { return }
                raceWinner = winner
                statusMessage = "导航节点已获取"
                debugPrint("[OSS竞速] 获胜来源：\(winner.source.rawValue)，地址：\(winner.node.urlString)")
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                statusMessage = "导航节点获取失败，请重试"
                debugPrint("[OSS竞速] 五路均未成功：\(error)")
            }
            isRacing = false
        }
    }
    
}
