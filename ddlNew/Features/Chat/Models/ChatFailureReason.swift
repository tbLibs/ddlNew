//
//  ChatFailureReason.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

enum ChatFailureReason: Int, Sendable {
    case unknown = 0, networkUnavailable, connectionNotReady, timeout, serverRejected, rateLimited, fileTooLarge, invalidResponse, connectionLost
    case blockedByMe, blockedByPeer, secureConnection
    nonisolated var isBlacklistRejection: Bool { self == .blockedByMe || self == .blockedByPeer }
    var message: String {
        switch self {
        case .networkUnavailable: return L10n.tr("网络不可用，请连接网络后重试")
        case .connectionNotReady: return L10n.tr("连接尚未就绪，请稍后重试")
        case .secureConnection: return L10n.tr("消息补发安全连接失败，请稍后重试")
        case .timeout: return L10n.tr("发送超时，可重新发送")
        case .serverRejected: return L10n.tr("服务器拒绝了这条消息")
        case .rateLimited: return L10n.tr("发送过于频繁，请稍后重试")
        case .fileTooLarge: return L10n.tr("附件过大，请选择较小文件")
        case .invalidResponse: return L10n.tr("服务器回执无效，请稍后重试")
        case .connectionLost: return L10n.tr("连接中断，请恢复连接后重试")
        case .unknown: return L10n.tr("发送失败，可重新发送")
        case .blockedByMe: return L10n.tr("已拉黑")
        case .blockedByPeer: return L10n.tr("对方已拒绝接受你的消息")
        }
    }
}

enum ChatClientError: LocalizedError {
    case sessionExpired, permission(String), invalidResponse, unavailable(String)
    var errorDescription: String? {
        switch self {
        case .sessionExpired: return L10n.tr("当前登录已结束，请返回重新进入")
        case .permission(let text), .unavailable(let text): return text
        case .invalidResponse: return L10n.tr("消息响应无效，请重试")
        }
    }
}
