//
//  OSSAuthResponseDecoder.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import CryptoKit
import Foundation
import SwiftProtobuf

/// 导航响应在类型、状态、解密或端点筛选阶段的失败原因。
enum OSSAuthResponseError: Error {
    /// 缺少用于派生解密密钥的 appID。
    case invalidAppID
    /// 不是 IM 服务器列表响应消息。
    case unexpectedMessageType
    /// 服务端返回非成功状态，保留原错误码和消息。
    case serverRejected(code: Int32, message: String)
    /// 服务端未提供加密响应体。
    case emptyResponseBody
    /// AES 解密失败或得到空数据。
    case decryptionFailed
    /// 解密成功，但没有同时可用的 TCP 与 HTTP 节点。
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

/// 按旧协议校验并解密 OSS Auth 的 Protobuf 响应。
enum OSSAuthResponseDecoder {
    /// 旧导航协议的成功状态码。
    private static let successCode: Int32 = 200_000

    static func decode(_ message: NavMessage, appID: String) throws -> OSSNavigationResult {
        guard !appID.isEmpty else { throw OSSAuthResponseError.invalidAppID }
        guard message.dataType == .imServerListResp,
              case .imServerListResponse(let response)? = message.dataBody else {
            throw OSSAuthResponseError.unexpectedMessageType
        }
        guard response.statusCode == successCode else {
            throw OSSAuthResponseError.serverRejected(
                code: response.statusCode,
                message: response.message
            )
        }
        guard !response.responseBody.isEmpty else {
            throw OSSAuthResponseError.emptyResponseBody
        }

        // 旧协议使用小写 MD5(appID) 作为响应 AES-128-ECB 的 secret。
        let secret = Insecure.MD5.hash(data: Data(appID.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        guard let plaintext = AesEncryptUtils.decryptBytes(response.responseBody, secret: secret),
              !plaintext.isEmpty else {
            throw OSSAuthResponseError.decryptionFailed
        }

        let body = try IMServerListResponseBody(serializedBytes: plaintext)
        let usable = body.imEndpoints.filter { endpoint in
            endpoint.status != "INACTIVE" &&
                !endpoint.ip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                endpoint.port > 0 && endpoint.port <= Int32(UInt16.max)
        }
        // 同一节点可能同时支持 TCP 和 HTTP，因此两类筛选不能互斥。
        let tcp = usable.filter { $0.protocols.contains("tcp") }
        let http = usable.filter { $0.protocols.contains("http") }
        guard !tcp.isEmpty, !http.isEmpty else {
            throw OSSAuthResponseError.missingUsableEndpoints
        }
        return OSSNavigationResult(body: body, tcpEndpoints: tcp, httpEndpoints: http)
    }
}
