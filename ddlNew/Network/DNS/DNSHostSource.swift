//
//  DNSHostSource.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

/// 与旧项目的五路 DNS 来源标记保持一致，供后续节点竞速识别来源。
enum DNSHostSource: String, CaseIterable, Sendable {
    /// 新版 APP TCP 数据；与旧 ALIDNS 导航来源分开。
    case dns1 = "DNS1_TCP"

    /// 阿里 HTTPDNS SDK 的 AAAA 记录。
    case aliAAAA = "ALIDNS"
    /// 腾讯 DoH 的 AAAA 记录。
    case tencentAAAA = "TENCENT_AAAA"
    /// Cloudflare DoH 的 TXT 记录。
    case cloudflareTXT = "CF_TXT"
    /// Cloudflare DoH 的 AAAA 记录。
    case cloudflareAAAA = "CF_AAAA"
    /// 阿里 DoH 的 TXT 记录。
    case aliTXT = "ALI_DOH_TXT"
    case oldResolver = "OLDRESOLVER"
    case cachedFallback = "CACHED_FALLBACK"
    case builtInFallback = "BUILTIN_FALLBACK"
    case ossHTTPDomestic = "OSS_HTTP_DOMESTIC"
    case ossHTTPOverseas = "OSS_HTTP_OVERSEAS"

    /// 降级来源也要保留在缓存，但首轮只启动这五路 DNS。
    static let primarySources: [DNSHostSource] = [.aliAAAA, .tencentAAAA, .cloudflareTXT, .cloudflareAAAA, .aliTXT]

    /// 分别保留缓存和内置地址的名额，服务端长列表不能挤掉内置恢复入口。
    nonisolated static func fallbackCandidates(cached: [String], builtIn: [String])
        -> [(source: DNSHostSource, address: String)] {
        var result: [(source: DNSHostSource, address: String)] = []
        var seen = Set<String>()
        for (source, addresses) in [(DNSHostSource.cachedFallback, cached), (.builtInFallback, builtIn)] {
            var count = 0
            for raw in addresses {
                let address = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !address.isEmpty, seen.insert(address).inserted else { continue }
                result.append((source, address))
                count += 1
                if count == 8 { break }
            }
        }
        return result
    }

}
