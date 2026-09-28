//
//  IMConnectionError.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

/// TCP/ECDH 初始化失败；不包含密钥或账号密码。
enum IMConnectionError: Error {
    case missingTCPNodes
    case allProbesFailed
    case handshakeFailed
    case timedOut
    case connectionLost
}
