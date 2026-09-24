//
//  DNSPayloadDecoder.swift
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//

import Foundation

struct DNSResolvedHost: Equatable, Sendable {
    let urlString: String
    let type: String
}

enum DNSPayloadDecoder {

    /// 将一个或多个 JSON 载荷中的主机与端口组合为节点。
    static func hosts(fromJSONPayloads payloads: [String]) -> [DNSResolvedHost] {
        let addresses = payloads.flatMap { addressesFromJSON($0) }
        return addresses.enumerated().map { index, address in
            DNSResolvedHost(urlString: address, type: index == 0 ? "1" : "2")
        }
    }

    /// 将旧项目编码在 AAAA 记录中的 JSON 还原并解析为节点。
    static func hosts(fromEncodedIPv6 records: [String]) -> [DNSResolvedHost] {
        hosts(fromJSONPayloads: [ipv6ToString(records)])
    }

    static func ipv6ToString(_ records: [String]) -> String {
        let fragments = records.compactMap { record -> (sequence: Int, hex: String)? in
            let address = record.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !address.isEmpty else { return nil }

            let prefix = String(address.prefix(2)).replacingOccurrences(of: ":", with: "")
            let sequence = Int(prefix, radix: 16) ?? 0
            let hex = String(address.dropFirst(min(2, address.count)))
                .replacingOccurrences(of: ":", with: "")
            return (sequence, hex)
        }

        let hexBytes = Array(fragments.sorted { $0.sequence < $1.sequence }
            .map(\.hex)
            .joined()
            .utf8)
        var plainBytes: [UInt8] = []

        for index in stride(from: 0, to: hexBytes.count, by: 2) {
            guard let high = hexValue(hexBytes[index]) else { return "" }
            let low: UInt8
            if index + 1 < hexBytes.count {
                guard let value = hexValue(hexBytes[index + 1]) else { return "" }
                low = value
            } else {
                // 旧实现会在奇数位十六进制结尾补 0。
                low = 0
            }

            let byte = (high << 4) | low
            if byte == 0 { break }
            plainBytes.append(byte)
        }

        return String(bytes: plainBytes, encoding: .utf8) ?? ""
    }

    private static func addressesFromJSON(_ text: String) -> [String] {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawHosts = object["2"] as? [Any] else {
            return []
        }

        let rawPorts = object["1"] as? [Any] ?? []
        let hasPorts = !rawPorts.isEmpty
        let ports = rawPorts.compactMap { validPort($0) }
        var addresses: [String] = []

        for rawHost in rawHosts {
            guard let host = rawHost as? String else { continue }
            let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedHost.isEmpty else { continue }

            if hasPorts {
                addresses.append(contentsOf: ports.map { "\(trimmedHost):\($0)" })
            } else {
                addresses.append(trimmedHost)
            }
        }

        return addresses
    }

    private static func validPort(_ value: Any) -> String? {
        let rawValue: String
        switch value {
        case let string as String:
            rawValue = string.trimmingCharacters(in: .whitespacesAndNewlines)
        case let number as NSNumber:
            rawValue = number.stringValue
        default:
            return nil
        }

        guard let port = UInt16(rawValue), port > 0 else { return nil }
        return String(port)
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: return byte - 48
        case 65...70: return byte - 55
        case 97...102: return byte - 87
        default: return nil
        }
    }
}
