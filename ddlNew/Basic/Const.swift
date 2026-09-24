//
//  Const.swift
//  ddlNew
//
//  Created by taobo on 2026/9/22.
//

import Foundation

/// OSS Auth 签名沿用旧项目的 DirectDecodeKeyId / DirectDecodeKeySecret。
let DirectDecodeKeyId = "671581_30185023923412521"
let DirectDecodeKeySecret = "0fc2f1c074fd24b3b13f23243297dc86"

/// 获取设备公网 IP 的 HTTPS 地址；沿用旧项目的两个服务，移除重复的 HTTP 地址。
let publicIPLookupURLs = [
    "https://ipinfo.io/ip",
    "https://checkip.amazonaws.com"
]

/// 阿里 HTTPDNS SDK 使用的账号、访问密钥和测试域名。
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

/// 腾讯 DoH AAAA 查询域名和主备服务地址。
let tencent_httpdns_test_domain  = "fbar.fbar.coerua.com"
let tencentURl = [
    "https://doh.pub/dns-query",
    "https://dns.pub/dns-query"
]


/// Cloudflare DoH 服务地址及查询域名。
let cf_doh_base_url = "https://cloudflare-dns.com/dns-query"
let cf_doh_test_domain = "jndnav.jiguanged.com"
