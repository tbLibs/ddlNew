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
        case .connecting: return "正在连接…"
        case .online: return "在线"
        case .reconnecting: return "重连中"
        case .retrying: return "连接失败，正在重连"
        case .offline: return "网络不可用"
        case .localFailure: return "恢复失败，请重试"
        }
    }
}

nonisolated enum IMConnectionEvent { case connecting, disconnected, failed, authenticated }
