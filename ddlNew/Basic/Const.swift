//
//  Const.swift
//  ddlNew
//
//  Created by taobo on 2026/9/22.
//

import Foundation

/// aliyun的账号
let aliyunDNSAccountId = "818331"
let aliyunDNSAccessKeyId = "818331_32775143437188096"
let aliyunDNSAccesskeySecret = "72ca8c7c99ee47bbb37db2f4ec774d47"
let ali_httpdns_test_domain  = "znav.znav.coerua.com"

/// 对应旧项目的 Z_DNS_TXT_AES_SECRET
let zDNSTXTAESSecret = "aslkdhiwuhdliqsjdh"

/// 阿里 DoH TXT 主、备解析地址
let aliDoHBaseURLs = [
    "https://223.5.5.5/resolve",
    "https://223.6.6.6/resolve"
]

/// 域名转 IPv4 时使用的阿里 DoH 地址。
let aliARecordBaseURLs = aliDoHBaseURLs + ["https://dns.alidns.com/resolve"]

/// 域名转 IPv4 时使用的 UDP DNS 服务器。
let dnsARecordServers = ["119.29.29.29", "114.114.114.114"]

/// 腾讯AAA
let tencent_httpdns_test_domain  = "fbar.fbar.coerua.com"
let tencentURl = [
    "https://doh.pub/dns-query",
    "https://dns.pub/dns-query"
]


/// Cloudflare DoH 常量
let cf_doh_base_url = "https://cloudflare-dns.com/dns-query"
let cf_doh_test_domain = "jndnav.jiguanged.com"
