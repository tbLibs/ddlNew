//
//  DNS1Payload.swift
//  ddlNew
//
//  Created by taobo on 2026/10/17.
//

import Foundation
import CryptoKit
import Darwin

nonisolated enum DNS1Error: Error { case invalidLicense, invalidPayload, unavailable }

/// APP 专用载荷：TCP 必须有效，HTTP 只是服务端明确给出的可选文件地址。
nonisolated struct DNS1Payload: Sendable, Equatable {
    let tcp: [DNS1TCPNode]
    let http: [URL]

    static func license(_ value: String) throws -> String {
        guard (1...62).contains(value.utf8.count), value.utf8.allSatisfy({
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        }) else { throw DNS1Error.invalidLicense }
        return value
    }

    /// IPv6 的前两个字节是大端序号，后十四字节是内容；乱序、重复、缺片统一校验。
    static func records(_ records: [String]) throws -> Self {
        guard !records.isEmpty, records.count <= 4096 else { throw DNS1Error.invalidPayload }
        var chunks: [Int: [UInt8]] = [:]
        for record in records {
            var bytes = [UInt8](repeating: 0, count: 16)
            guard inet_pton(AF_INET6, record, &bytes) == 1 else { throw DNS1Error.invalidPayload }
            let index = Int(bytes[0]) * 256 + Int(bytes[1])
            let chunk = Array(bytes.dropFirst(2))
            if let old = chunks[index], old != chunk { throw DNS1Error.invalidPayload }
            chunks[index] = chunk
        }
        let indices = chunks.keys.sorted()
        guard let first = indices.first, first == 0 || first == 1,
              indices == Array(first..<(first + indices.count)) else { throw DNS1Error.invalidPayload }
        let bytes = indices.flatMap { chunks[$0]! }.prefix { $0 != 0 }
        guard let text = String(bytes: bytes, encoding: .utf8) else { throw DNS1Error.invalidPayload }
        return try decode(text, requireJSON: false)
    }

    static func decode(_ text: String, requireJSON: Bool) throws -> Self {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var tcpValues: [String]
        var httpValues: [String] = []
        if let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] {
            guard let nodes = object["tcp"] as? [String] else { throw DNS1Error.invalidPayload }
            tcpValues = nodes
            httpValues = object["http"] as? [String] ?? []
        } else {
            guard !requireJSON, !text.hasPrefix("{"), !text.hasPrefix("[") else { throw DNS1Error.invalidPayload }
            tcpValues = text.components(separatedBy: ",")
        }
        var tcp: [DNS1TCPNode] = []
        for value in tcpValues {
            if let node = DNS1TCPNode(value), !tcp.contains(node) { tcp.append(node) }
        }
        guard !tcp.isEmpty, tcp.count <= 64 else { throw DNS1Error.invalidPayload }
        var http: [URL] = []
        for value in httpValues {
            if let url = httpURL(value), !http.contains(url) { http.append(url) }
        }
        return Self(tcp: tcp, http: http)
    }

    /// BIN 的密钥派生沿用旧协议，但只接受解密后的 JSON TCP 载荷。
    static func bin(_ data: Data, license: String) throws -> Self {
        _ = try Self.license(license)
        let secret = Insecure.MD5.hash(data: Data(license.utf8)).map { String(format: "%02x", $0) }.joined()
        var candidates = [data]
        if let text = String(data: data, encoding: .utf8),
           let decoded = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)) { candidates.append(decoded) }
        for candidate in candidates {
            if let plain = AesEncryptUtils.decryptBytes(candidate, secret: secret),
               let text = String(data: plain, encoding: .utf8),
               let payload = try? decode(text, requireJSON: true) { return payload }
        }
        throw DNS1Error.invalidPayload
    }

    static func httpURL(_ value: String) -> URL? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains(where: { $0.isWhitespace }) else { return nil }
        let raw = value.contains("://") ? value : "https://" + value
        guard let parts = URLComponents(string: raw), ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil,
              parts.port == nil || (1...65535).contains(parts.port!) else { return nil }
        return parts.url
    }
}

nonisolated struct DNS1TCPNode: Sendable, Equatable {
    let host: String
    let port: UInt16

    /// 不接受 URL、WebSocket 或推算端口；IPv6 必须带方括号和显式端口。
    init?(_ address: String) {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains(where: { $0.isWhitespace }),
              !value.contains("/"), !value.contains("@"), !value.contains("?"), !value.contains("#") else { return nil }
        let host: String
        let portText: String
        if value.hasPrefix("["), let end = value.firstIndex(of: "]") {
            host = String(value[value.index(after: value.startIndex)..<end])
            let tail = value[value.index(after: end)...]
            guard tail.hasPrefix(":"), !host.contains("%") else { return nil }
            portText = String(tail.dropFirst())
            var bytes = [UInt8](repeating: 0, count: 16)
            guard inet_pton(AF_INET6, host, &bytes) == 1 else { return nil }
        } else {
            let parts = value.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            host = String(parts[0]); portText = String(parts[1])
            guard !host.isEmpty, host.utf8.count <= 253,
                  host.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({ label in
                      !label.isEmpty && label.count <= 63 && label.first != "-" && label.last != "-" &&
                      label.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 }
                  }) else { return nil }
        }
        guard !portText.isEmpty, portText.utf8.allSatisfy({ (48...57).contains($0) }),
              let port = UInt16(portText), port > 0 else { return nil }
        self.host = host; self.port = port
    }

    var address: String { host.contains(":") ? "[\(host)]:\(port)" : "\(host):\(port)" }
}
