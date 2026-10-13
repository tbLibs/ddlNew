//
//  Const.swift
//  ddlNew
//
//  Created by taobo on 2026/9/22.
//

import Foundation

// MARK: - App 打包类型

/// 默认 appType：.common = 0（公共打包），.independent = 1（独立打包）。
let DefaultAppType: IMServerListRequest.DataType = .common

// MARK: - 本地状态存储

/// 保存最新一份 OSS 导航状态的固定 AppStorage key，不拼接邀请码。
let ossNavigationAppStorageKey = "ddlNew.ossNavigation.v1"

/// 保存最新已选 HTTP API Host 的固定 AppStorage key，不拼接邀请码。
let ossSelectedHTTPHostAppStorageKey = "ddlNew.selectedHTTPHost.v1"

/// 保存最新业务系统配置的固定 AppStorage key，不拼接邀请码。
let systemConfigAppStorageKey = "ddlNew.systemConfig.v1"

/// 业务请求的设备 UUID 存储 key。
let businessDeviceUUIDAppStorageKey = "ddlNew.businessDeviceUUID.v1"

/// 最新用户资料的固定 key；不保存 token、deviceSecret 或密码。
let userInfoAppStorageKey = "ddlNew.userInfo.v1"
let userRoleAuthorityAppStorageKey = "ddlNew.userRoleAuthority.v1"

/// 当前会话凭据的 Keychain 标识，不拼接邀请码。
let userCredentialKeychainService = "ddlNew.userSession"
let userCredentialKeychainAccount = "currentSession.v1"

/// 登录页记住密码的偏好，首次使用默认开启；此 key 不存放密码。
let loginRememberPasswordAppStorageKey = "ddlNew.login.rememberPassword.v1"

/// 登录表单的独立 Keychain 标识，不与 token、设备凭据混用。
let rememberedLoginKeychainService = "ddlNew.rememberedLogin"
let rememberedLoginKeychainAccount = "loginForm.v1"

// MARK: - 登录页外部链接

/// 登录页 Safari 浏览器打开的隐私政策和使用支持地址。
let privacyPolicyURLString = "https://gitlab.yunliaoliao.com/c/privacy.html"
let usageSupportURLString = "https://gitlab.yunliaoliao.com/c/support.html"

// MARK: - 业务接口与 OSS 认证

/// 老项目业务接口使用的组织标识。
let businessOrgName = "1595975575091130369"

/// OSS Auth 签名沿用旧项目的 DirectDecodeKeyId / DirectDecodeKeySecret。
let DirectDecodeKeyId = "671581_30185023923412521"
let DirectDecodeKeySecret = "0fc2f1c074fd24b3b13f23243297dc86"

// MARK: - 公网地址与 DNS 解析

/// 获取设备公网 IP 的 HTTPS 地址；沿用旧项目的两个服务，移除重复的 HTTP 地址。
let publicIPLookupURLs = [
    "https://ipinfo.io/ip",
    "https://checkip.amazonaws.com"
]

/// 阿里 HTTPDNS SDK 使用的账号、访问密钥和测试域名。
let aliyunDNSAccountId = "899981"
let aliyunDNSAccessKeyId = "899981_32929921960122368"
let aliyunDNSAccesskeySecret = "d298cd440c204fc28f9170a01f7d45e6"
let ali_httpdns_test_domain  = "nav.ziyouyi.com"

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
let tencent_httpdns_test_domain  = "nav.ziyouyi.com"
let tencentURl = [
    "https://doh.pub/dns-query",
    "https://dns.pub/dns-query"
]


/// Cloudflare DoH 服务地址及查询域名。
let cf_doh_base_url = "https://cloudflare-dns.com/dns-query"
let cf_doh_test_domain = "jndnav.jiguanged.com"


// MARK: - 邀请码导航降级（旧版 Resolver / TCP / OSS HTTP）
let legacyNavigationDomain = "nav.rnzkzw.com"
let builtInNavigationDomesticAddresses = [
    "nav.hoqxy.com:18087",
    "ga-bp1ejvtbm2atv7ih5glwg.aliyunga0018.com:18087",
    "awsnav.hoqxy.com:18087",
    "aws1nav.hoqxy.com:18087"
]
let builtInNavigationOverseasAddresses: [String] = []
let builtInOSSHTTPBaseURLs = [
    "https://prnav1.oss-accelerate.aliyuncs.com",
    "https://cmnav1.oss-accelerate.aliyuncs.com"
]

/// 已确认强制修改密码的最小身份标记；只含用户 UID 与所属俱乐部。
let loginForcedPasswordRequirementAppStorageKey = "ddlNew.loginForcedPasswordRequirement.v1"
