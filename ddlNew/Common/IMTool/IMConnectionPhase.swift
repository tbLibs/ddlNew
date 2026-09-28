//
//  IMConnectionPhase.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

/// 初始化进度同时供邀请码页和登录页读取；就绪不等于账号已登录。
enum IMConnectionPhase: Equatable {
    case idle
    case connecting
    case fetchingConfiguration
    case ready
    case failed(String)

    var message: String {
        switch self {
        case .idle: return "连接尚未准备"
        case .connecting: return "正在恢复 TCP/ECDH 连接…"
        case .fetchingConfiguration: return "连接已建立，正在获取系统配置…"
        case .ready: return "连接已就绪"
        case .failed(let message): return message
        }
    }

    var isBusy: Bool {
        self == .connecting || self == .fetchingConfiguration
    }
}
