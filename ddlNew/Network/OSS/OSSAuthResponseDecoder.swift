//
//  OSSAuthResponseDecoder.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation
import SwiftProtobuf

/// 本地 DNS1 导航容器中没有有效业务 TCP 节点。
enum OSSAuthResponseError: Error {
    case missingUsableEndpoints
}

/// 导航响应以及从中筛出的两类可用 IM 节点。
struct OSSNavigationResult: Sendable {
    /// 完整响应体，保留服务端下发的缓存、兜底和配置数据。
    let body: IMServerListResponseBody
    /// 未标记 INACTIVE 且支持 TCP 的节点。
    let tcpEndpoints: [IMServerEndpoint]
    /// 未标记 INACTIVE 且支持 HTTP 的节点。
    let httpEndpoints: [IMServerEndpoint]
}

/// 校验 DNS1 映射到本地 Protobuf 容器的节点，不发起旧 OSS 请求。
enum OSSAuthResponseDecoder {
    /// 新响应与本地缓存共用同一套端点校验，避免恢复出不可连接的导航状态。
    nonisolated static func navigation(from body: IMServerListResponseBody) throws -> OSSNavigationResult {
        let usable = body.imEndpoints.filter { endpoint in
            endpoint.status != "INACTIVE" &&
                DNS1TCPNode(endpoint.ip.contains(":") ? "[\(endpoint.ip)]:\(endpoint.port)" : "\(endpoint.ip):\(endpoint.port)") != nil
        }
        // 同一节点可能同时支持 TCP 和 HTTP，因此两类筛选不能互斥。
        let tcp = usable.filter { $0.protocols.contains("tcp") }
        let http = usable.filter { $0.protocols.contains("http") }
        guard !tcp.isEmpty, body.meta.navVersion.hasPrefix("DNS1:v2:") else {
            throw OSSAuthResponseError.missingUsableEndpoints
        }
        return OSSNavigationResult(body: body, tcpEndpoints: tcp, httpEndpoints: http)
    }
}
