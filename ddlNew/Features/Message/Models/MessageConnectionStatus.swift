//
//  MessageConnectionStatus.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//

import Foundation

nonisolated enum MessageConnectionStatus: Equatable {
    case connecting, online, reconnecting, retrying, offline, localFailure

    static func resolve(network: Bool?, authenticated: Bool, retrying: Bool,
                        failed: Bool, localFailure: String?) -> Self {
        if network == false { return .offline }
        if localFailure != nil { return .localFailure }
        if authenticated { return .online }
        if failed { return .retrying }
        return retrying ? .reconnecting : .connecting
    }

    var title: String {
        switch self {
        case .connecting: return L10n.tr("正在连接…")
        case .online: return L10n.tr("在线")
        case .reconnecting: return L10n.tr("重连中")
        case .retrying: return L10n.tr("连接失败，正在重连")
        case .offline: return L10n.tr("网络不可用")
        case .localFailure: return L10n.tr("恢复失败，请重试")
        }
    }
}

nonisolated enum IMConnectionEvent { case connecting, disconnected, failed, authenticated }
