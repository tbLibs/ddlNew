//
//  AccountLoginError.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

/// 保留 SDK 业务码供后续验证码、安全验证页面分流。
nonisolated enum AccountLoginError: LocalizedError {
    case emptyAccount
    case emptyPassword
    case connectionNotReady
    case connectionChanged
    case unsupportedAccountLogin
    case invalidEncryptKey
    case encryptionFailed
    case invalidResponse
    case unavailableOnSimulator
    case timedOut
    case businessFailure(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .emptyAccount: return "请输入会员卡号"
        case .emptyPassword: return "请输入密码"
        case .connectionNotReady: return "连接尚未就绪，请稍后重试"
        case .connectionChanged: return "连接已发生变化，请重新登录"
        case .unsupportedAccountLogin: return "当前俱乐部未开启账号密码登录"
        case .invalidEncryptKey: return "获取加密密钥失败，请重新登录"
        case .encryptionFailed: return "密码加密失败，请重试"
        case .invalidResponse: return "登录响应数据不完整，请重试"
        case .unavailableOnSimulator: return "密码加密需要真机运行"
        case .timedOut: return "登录请求超时，请重试"
        case .businessFailure(let code, let message):
            // 不绕过服务端校验；验证码和安全码页面在下一阶段接入。
            switch code {
            case 2036, 40019, 50000, 50001:
                return "账号或密码错误，请重新输入（\(code)）"
            case 40064, 50002, 51002, 51006, 450010:
                return "需要完成验证码验证（\(code)），验证码流程尚未接入"
            case 10009:
                return "需要安全码验证，安全验证流程尚未接入"
            default:
                return message.isEmpty ? "登录请求失败（\(code)）" : "\(message)（\(code)）"
            }
        }
    }
}
