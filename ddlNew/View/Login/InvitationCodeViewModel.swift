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
    @Published var invitationCode = "" {
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

    @Published private(set) var isRacing = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var raceWinner: OSSRaceWinner?

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
                let winner = try await OSSNodeRaceCoordinator.race(
                    appID: appID,
                    credentials: credentials
                )
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
