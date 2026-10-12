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
    case verificationUnavailable
    case invalidVerificationAnswer
    case verificationAttemptsExceeded
    case securityVerificationExpired
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
        case .verificationUnavailable: return "当前验证方式暂不可用，请稍后重新登录"
        case .invalidVerificationAnswer: return "验证内容为空，请重新登录并完成验证"
        case .verificationAttemptsExceeded: return "验证尝试次数过多，请重新登录"
        case .securityVerificationExpired: return "安全码验证已失效，请重新登录"
        case .businessFailure(let code, let message):
            switch code {
            case 2036, 40019, 50000, 50001:
                return "账号或密码错误，请重新输入，错误码：\(code)"
            case 40064, 50002, 51002, 51006, 450010:
                return "验证码验证失败，请重新登录（\(code)）"
            case 10009:
                return "需要安全码验证，请重新登录"
            case 40069, 40070, 40071:
                return "安全码不正确，请重新输入"
            case 40072, 40073:
                return "安全码验证已失效，请重新登录"
            default:
                return message.isEmpty ? "登录请求失败（\(code)）" : "\(message)（\(code)）"
            }
        }
    }
}
