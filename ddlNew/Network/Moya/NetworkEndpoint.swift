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
        case .cloudflareDoHTXT:
            ""
        case .cloudflareAAAA:
            ""
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .tencentDoHAAAA, .cloudflareDoHTXT, .cloudflareAAAA:
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
        case .tencentDoHAAAA, .cloudflareDoHTXT, .cloudflareAAAA:
            header["Accept"] = "application/dns-json"
        }
        return header
    }
}
