//
//  OSSAuthResponseDecoder.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import CryptoKit
import Foundation
import SwiftProtobuf

enum OSSAuthResponseError: Error {
    case invalidAppID
    case unexpectedMessageType
    case serverRejected(code: Int32, message: String)
    case emptyResponseBody
    case decryptionFailed
    case missingUsableEndpoints
}

/// 导航响应以及从中筛出的两类可用 IM 节点。
struct OSSNavigationResult: Sendable {
    let body: IMServerListResponseBody
    let tcpEndpoints: [IMServerEndpoint]
    let httpEndpoints: [IMServerEndpoint]
}

enum OSSAuthResponseDecoder {
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
