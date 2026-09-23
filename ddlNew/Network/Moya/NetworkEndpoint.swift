//
//  NetworkEndpoint.swift
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//

import Foundation
import Moya
import Alamofire

enum ApiType {
    /// 腾讯DNS
    case tencentDoHAAAA(baseurl: String)
    /// 阿里 DoH TXT
    case aliDoHTXT(baseURL: URL, timestamp: String, signature: String)
    /// cloudflareDoHTXT
    case cloudflareDoHTXT
    /// CloudflareAAAA
    case cloudflareAAAA
    
}

extension ApiType: TargetType {
    var baseURL: URL {
        switch self {
        case .tencentDoHAAAA(let baseurl):
            return URL(string: baseurl)!
        case .aliDoHTXT(let baseURL, _, _):
            return baseURL
        case .cloudflareDoHTXT:
            return URL(string: cf_doh_base_url)!
        case .cloudflareAAAA:
            return URL(string: cf_doh_base_url)!
        }
    }
    
    var path: String {
        switch self {
        case .tencentDoHAAAA:
            ""
        case .aliDoHTXT:
            ""
        case .cloudflareDoHTXT:
            ""
        case .cloudflareAAAA:
            ""
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .tencentDoHAAAA, .aliDoHTXT, .cloudflareDoHTXT, .cloudflareAAAA:
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
        }
    }
    
    var headers: [String : String]? {
        var header = [String : String]()
        switch self {
        case .tencentDoHAAAA, .aliDoHTXT, .cloudflareDoHTXT, .cloudflareAAAA:
            header["Accept"] = "application/dns-json"
        }
        return header
    }
}
