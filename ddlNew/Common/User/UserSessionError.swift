//
//  UserSessionError.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

nonisolated enum UserSessionError: LocalizedError {
    case invalidData
    case keychainFailure(Int32)
    case databaseNotReady
    case authenticationTimedOut
    case authenticationRejected(code: Int, message: String)

    /// 数据损坏或服务端明确拒绝不能继续自动恢复；断网、超时不删除登录凭据。
    var invalidatesCachedSession: Bool {
        switch self {
        case .invalidData, .authenticationRejected: return true
        case .keychainFailure, .databaseNotReady, .authenticationTimedOut: return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidData: return "用户会话数据不完整，请重新登录"
        case .keychainFailure(let status): return "保存或读取登录凭据失败（\(status)），请重试"
        case .databaseNotReady: return "用户数据库初始化失败，请重新登录"
        case .authenticationTimedOut: return "TCP 用户认证超时，请检查网络后重新登录"
        case .authenticationRejected(let code, let message):
            return message.isEmpty ? "用户认证失效，请重新登录（\(code)）" : "\(message)（\(code)）"
        }
    }
}
