//
//  AliDoHTXTDecoder.swift
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//

import Foundation
import CryptoKit

struct AliDoHHost: Equatable {
    let urlString: String
    let type: String
}

enum AliDoHTXTDecoder {

    static func signature(timestamp: String) -> String {
        let source = aliyunDNSAccountId
            + aliyunDNSAccesskeySecret
            + timestamp
            + ali_httpdns_test_domain
            + aliyunDNSAccessKeyId
        return SHA256.hash(data: Data(source.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func decode(answers: [DoHResponse.Answer], aesSecret: String) -> [AliDoHHost] {
        var hosts: [AliDoHHost] = []

        for answer in answers {
            let cipher = joinedTXTChunks(answer.data)
            guard let plainText = AesEncryptUtils.decrypt(cipher, secret: aesSecret),
                  let jsonData = plainText.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let rawHosts = object["2"] as? [Any] else {
                continue
            }

            let rawPorts = object["1"] as? [Any] ?? []
            let hasPorts = !rawPorts.isEmpty
            let ports = rawPorts.compactMap { validPort($0) }

            for rawHost in rawHosts {
                guard let host = rawHost as? String else { continue }
                let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedHost.isEmpty else { continue }

                if hasPorts {
                    for port in ports {
                        hosts.append(AliDoHHost(
                            urlString: "\(trimmedHost):\(port)",
                            type: hosts.isEmpty ? "1" : "2"
                        ))
                    }
                } else {
                    hosts.append(AliDoHHost(
                        urlString: trimmedHost,
                        type: hosts.isEmpty ? "1" : "2"
                    ))
                }
            }
        }

        return hosts
    }

    // DNS TXT 可能由多个引号包裹的片段组成，需要先拼接 Base64。
    private static func joinedTXTChunks(_ data: String) -> String {
        var chunks: [String] = []
        var current = ""
        var inQuote = false

        for character in data {
            if character == "\"" {
                if inQuote {
                    chunks.append(current)
                    current = ""
                }
                inQuote.toggle()
            } else if inQuote {
                current.append(character)
            }
        }

        if !chunks.isEmpty {
            return chunks.joined()
        }

        let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 2, trimmed.first == "\"", trimmed.last == "\"" {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
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

}
