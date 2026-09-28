//
//  DNSHostSource.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

/// 与旧项目的五路 DNS 来源标记保持一致，供后续节点竞速识别来源。
enum DNSHostSource: String, CaseIterable, Sendable {
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
}
