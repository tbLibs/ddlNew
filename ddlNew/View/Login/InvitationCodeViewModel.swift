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
    @Published var invitationCode = ""
    
    /// 点击连接俱乐部
    func clickClub() {
        HostNodeRaceManager.shared.aliAAATest()
        
        Task {
            let arr = try? await HostNodeRaceManager.shared.tencentDoHAAAA()
            debugPrint(arr ?? [])
        }
        
        HostNodeRaceManager.shared.cloudflareDoHTXT()
        HostNodeRaceManager.shared.cloudflareDoHAAAA()
        Task {
            let arr = try? await HostNodeRaceManager.shared.aliDoHTXT()
            debugPrint(arr ?? [])
        }
        
    }
    
}
