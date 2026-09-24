//
//  NetworkEndpoint.swift
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//

import Foundation
import Moya
import Alamofire

/// 五路 DNS 及归一化阶段 A 记录查询所用的 Moya 目标。
enum ApiType {
    
    /// 腾讯 DoH AAAA 查询，主备服务地址由调用方传入。
    case tencentDoHAAAA(baseurl: String)
    
    /// 阿里 DoH TXT
    case aliDoHTXT(baseURL: URL, timestamp: String, signature: String)
    
    /// Cloudflare DoH TXT 查询。
    case cloudflareDoHTXT
    
    /// Cloudflare DoH AAAA 查询。
    case cloudflareAAAA
    
    /// 将 DNS 返回的域名归一化为 IPv4 时使用的阿里 DoH A 查询。
    case aliDoHA(baseURL: URL, domain: String)
    
    /// 将 DNS 返回的域名归一化为 IPv4 时使用的 Cloudflare DoH A 查询。
    case cloudflareA(domain: String)
    
}

extension ApiType: TargetType {
    var baseURL: URL {
        switch self {
        case .tencentDoHAAAA(let baseurl):
            return URL(string: baseurl)!
        case .aliDoHTXT(let baseURL, _, _):
            return baseURL
        case .aliDoHA(let baseURL, _):
            return baseURL
        case .cloudflareDoHTXT, .cloudflareAAAA, .cloudflareA:
            return URL(string: cf_doh_base_url)!
        }
    }
    
    var path: String {
        switch self {
        case .tencentDoHAAAA, .aliDoHTXT, .cloudflareDoHTXT,
             .cloudflareAAAA, .aliDoHA, .cloudflareA:
            ""
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .tencentDoHAAAA, .aliDoHTXT, .cloudflareDoHTXT,
             .cloudflareAAAA, .aliDoHA, .cloudflareA:
            .get
        }
    }
    
    var task: Moya.Task {
        switch self {
        case .tencentDoHAAAA:
            return .requestParameters(
                parameters: ["name": tencent_httpdns_test_domain, "type": "AAAA"],
                encoding: URLEncoding.queryString
            )
        case .aliDoHTXT(_, let timestamp, let signature):
            return .requestParameters(
                parameters: [
                    "name": ali_httpdns_test_domain,
                    "type": "TXT",
                    "uid": aliyunDNSAccountId,
                    "ak": aliyunDNSAccessKeyId,
                    "ts": timestamp,
                    "key": signature
                ],
                encoding: URLEncoding.queryString
            )
        case .cloudflareDoHTXT:
            return .requestParameters(
                parameters: ["name": cf_doh_test_domain, "type": "TXT"],
                encoding: URLEncoding.queryString
            )
        case .cloudflareAAAA:
            return .requestParameters(
                parameters: ["name": cf_doh_test_domain, "type": "AAAA"],
                encoding: URLEncoding.queryString
            )
        case .aliDoHA(_, let domain), .cloudflareA(let domain):
            return .requestParameters(
                parameters: ["name": domain, "type": "A"],
                encoding: URLEncoding.queryString
            )
        }
    }
    
    var headers: [String : String]? {
        var header = [String : String]()
        switch self {
        case .tencentDoHAAAA, .aliDoHTXT, .cloudflareDoHTXT,
             .cloudflareAAAA, .aliDoHA, .cloudflareA:
            header["Accept"] = "application/dns-json"
        }
        return header
    }
}
