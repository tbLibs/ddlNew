//
//  AccountLoginPhase.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

/// 接口成功后还需保存会话、初始化 SDK 和等待用户 AUTH，才算本轮登录完成。
enum AccountLoginPhase: Equatable {
    case idle
    case fetchingKey
    case submitting
    case savingSession
    case configuringSDK
    case authenticating
    case succeeded
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .fetchingKey, .submitting, .savingSession, .configuringSDK, .authenticating: return true
        default: return false
        }
    }

    var buttonTitle: String {
        switch self {
        case .fetchingKey: return "正在获取加密密钥…"
        case .submitting: return "正在登录…"
        case .savingSession: return "正在保存会话…"
        case .configuringSDK: return "正在配置用户…"
        case .authenticating: return "正在认证 TCP 用户…"
        case .succeeded: return "已登录"
        default: return "登录"
        }
    }
}
