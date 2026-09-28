//
//  IMUserAuthenticationState.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

/// 与访客 ECDH 就绪分开：只有用户 AUTH 回执成功才进入 ready。
enum IMUserAuthenticationState: Equatable {
    case idle
    case authenticating
    case ready
    /// SDK 保留用户身份自行重连，不退回访客连接。
    case reconnecting
    case failed(String)

    var message: String {
        switch self {
        case .idle: return "尚未进行用户认证"
        case .authenticating: return "正在等待 TCP 用户认证…"
        case .ready: return "登录成功，TCP 用户认证已通过"
        case .reconnecting: return "用户连接已断开，SDK 正在重新连接和认证…"
        case .failed(let message): return message
        }
    }
}
