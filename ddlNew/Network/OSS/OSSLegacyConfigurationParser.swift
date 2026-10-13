import Foundation
import CryptoKit
import Darwin

/// 旧 OSS JSON 里的 sort 可作为无显式端口的 TCP 地址的兼容端口。
nonisolated struct OSSLegacyEndpoint: Equatable, Sendable {
    let host: String
    let port: UInt16
}

nonisolated struct OSSLegacyConfiguration: Sendable {
    let version: String
    let http: [OSSLegacyEndpoint]
    let tcp: [OSSLegacyEndpoint]
    let httpNodePreference: OSSLegacyHTTPNodePreference
}

/// 旧导航 HTTP 择优开关与周期独立于新版 TCP enable_network_detect。
nonisolated struct OSSLegacyHTTPNodePreference: Equatable, Sendable {
    let enabled: Bool
    let intervalSeconds: Int
}

enum OSSLegacyConfigurationError: Error {
    case invalidPayload
    case missingEndpoints
    case decryptionFailed
}

/// 独立验证旧 endpoints.http/tcp.ipList/dnsList；不保存旧协议里的证书、私钥。
nonisolated enum OSSLegacyConfigurationParser {
    @MainActor
    static func decodeEncrypted(_ data: Data, lastLiceseId: String) throws -> OSSLegacyConfiguration {
        guard !data.isEmpty, data.count <= 1_048_576, !lastLiceseId.isEmpty,
              let body = String(data: data, encoding: .utf8) else {
            throw OSSLegacyConfigurationError.invalidPayload
        }
        let cipher = body.components(separatedBy: .whitespacesAndNewlines).joined()
        let secret = Insecure.MD5.hash(data: Data(lastLiceseId.utf8))
            .map { String(format: "%02x", $0) }.joined()
        guard let plaintext = AesEncryptUtils.decrypt(cipher, secret: secret) else {
            throw OSSLegacyConfigurationError.decryptionFailed
        }
        return try parse(Data(plaintext.utf8))
    }

    static func parse(_ data: Data) throws -> OSSLegacyConfiguration {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let endpoints = root["endpoints"] as? [String: Any] else {
            throw OSSLegacyConfigurationError.invalidPayload
        }
        func nodes(_ name: String) throws -> [OSSLegacyEndpoint] {
            guard let group = endpoints[name] as? [String: Any] else {
                throw OSSLegacyConfigurationError.invalidPayload
            }
            var result: [OSSLegacyEndpoint] = []
            for key in ["ipList", "dnsList"] {
                guard let raw = group[key], !(raw is NSNull) else { continue }
                guard let items = raw as? [[String: Any]] else {
                    throw OSSLegacyConfigurationError.invalidPayload
                }
                for item in items.prefix(64) {
                    guard let address = item["ip"] as? String else {
                        throw OSSLegacyConfigurationError.invalidPayload
                    }
                    var fallback = name == "http" ? 443 : 0
                    if let rawSort = item["sort"] {
                        guard rawSort is String || rawSort is NSNumber else {
                            throw OSSLegacyConfigurationError.invalidPayload
                        }
                        if name == "tcp" {
                            let value = (rawSort as? String) ?? (rawSort as? NSNumber)?.stringValue ?? ""
                            fallback = Int(value) ?? 0
                        }
                    }
                    if let node = endpoint(address, defaultPort: fallback, http: name == "http"),
                       !result.contains(node) { result.append(node) }
                }
            }
            return result
        }
        let http = try nodes("http")
        let tcp = try nodes("tcp")
        guard !http.isEmpty, !tcp.isEmpty else { throw OSSLegacyConfigurationError.missingEndpoints }
        let enabled: Bool
        if let value = root["is_merge_version"] as? NSNumber { enabled = value.boolValue }
        else if let value = root["is_merge_version"] as? String {
            enabled = ["true", "1"].contains(value.lowercased())
        } else { enabled = false }
        let interval = (root["ping_interval_second"] as? NSNumber)?.intValue
            ?? (root["ping_interval_second"] as? String).flatMap(Int.init) ?? 0
        return OSSLegacyConfiguration(version: root["version"] as? String ?? "", http: http, tcp: tcp,
            httpNodePreference: OSSLegacyHTTPNodePreference(enabled: enabled, intervalSeconds: interval))
    }

    static func endpoint(_ address: String, defaultPort: Int, http: Bool = false) -> OSSLegacyEndpoint? {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains(where: { $0.isWhitespace }) else { return nil }
        let host: String
        let port: Int
        if value.contains("://") {
            guard http, let url = URLComponents(string: value),
                  url.scheme == "http" || url.scheme == "https",
                  let parsedHost = url.host, url.user == nil, url.password == nil,
                  url.query == nil, url.fragment == nil,
                  url.path.isEmpty || url.path == "/" else { return nil }
            host = parsedHost.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            port = url.port ?? defaultPort
        } else if value.hasPrefix("[") {
            guard let closing = value.firstIndex(of: "]") else { return nil }
            host = String(value[value.index(after: value.startIndex)..<closing])
            let suffix = value[value.index(after: closing)...]
            if suffix.isEmpty { port = defaultPort }
            else {
                guard suffix.hasPrefix(":"), let parsed = Int(suffix.dropFirst()) else { return nil }
                port = parsed
            }
        } else if value.filter({ $0 == ":" }).count == 1 {
            let parts = value.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2, let parsed = Int(parts[1]) else { return nil }
            host = String(parts[0]); port = parsed
        } else {
            host = value; port = defaultPort
        }
        guard validHost(host), let validPort = UInt16(exactly: port), validPort > 0 else { return nil }
        return OSSLegacyEndpoint(host: host, port: validPort)
    }

    static func validHost(_ host: String) -> Bool {
        guard !host.isEmpty else { return false }
        var ipv6 = in6_addr()
        if host.contains(":") { return inet_pton(AF_INET6, host, &ipv6) == 1 }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._")
        return host.unicodeScalars.allSatisfy { allowed.contains($0) }
            && host.contains(where: { $0.isLetter || $0.isNumber })
    }
}
