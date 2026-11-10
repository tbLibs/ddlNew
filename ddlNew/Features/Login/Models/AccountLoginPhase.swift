//
//  AccountLoginPhase.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

/// 接口成功后还需保存会话、初始化 SDK 和等待用户 AUTH，才算本轮登录完成。
enum AccountLoginPhase: Equatable {
    case idle
    case checkingAccount
    case fetchingKey
    case submitting
    case verifying
    case savingSession
    case configuringSDK
    case authenticating
    case succeeded
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .checkingAccount, .fetchingKey, .submitting, .verifying, .savingSession, .configuringSDK, .authenticating: return true
        default: return false
        }
    }

    var buttonTitle: String {
        switch self {
        case .checkingAccount: return L10n.tr("正在检查账号…")
        case .fetchingKey: return L10n.tr("正在获取加密密钥…")
        case .submitting: return L10n.tr("正在登录…")
        case .verifying: return L10n.tr("等待完成验证…")
        case .savingSession: return L10n.tr("正在保存会话…")
        case .configuringSDK: return L10n.tr("正在配置用户…")
        case .authenticating: return L10n.tr("正在认证 TCP 用户…")
        case .succeeded: return L10n.tr("已登录")
        default: return L10n.tr("登录")
        }
    }
}
