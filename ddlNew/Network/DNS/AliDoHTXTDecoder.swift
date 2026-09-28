//
//  AliDoHTXTDecoder.swift
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//

import Foundation
import CryptoKit

/// 阿里 TXT 解密后的节点与其他 DNS 来源共用地址模型。
typealias AliDoHHost = DNSResolvedHost

/// 校验阿里 DoH TXT 请求，并解密响应中的 OSS 节点载荷。
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
        let payloads = answers.compactMap { answer -> String? in
            let cipher = joinedTXTChunks(answer.data)
            guard !cipher.isEmpty else { return nil }
            return AesEncryptUtils.decrypt(cipher, secret: aesSecret)
        }
        return DNSPayloadDecoder.hosts(fromJSONPayloads: payloads)
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

}
