//
//  HostNodeRaceManager.swift
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//

import Foundation
import Moya
import ObjectMapper
import RxMoya
import RxSwift

struct DoHResponse: Mappable {
    var status: Int?
    var answers: [Answer]?

    init?(map: Map) {}

    mutating func mapping(map: Map) {
        status <- map["Status"]
        answers <- map["Answer"]
    }

    struct Answer: Mappable {
        var data = ""

        init?(map: Map) {}

        mutating func mapping(map: Map) {
            data <- map["data"]
        }
    }
}

enum DoHError: Error {
    case invalidURL
    case invalidResponse
    case emptyAnswer
}


class HostNodeRaceManager {
    
    let disposeBag = DisposeBag()

    private init() {}
    static let shared = HostNodeRaceManager()
    
    /// Resolver DNS（阿里AAA解析器）
    func aliAAATest() {
        
        let resolver = DNSResolver.share()
        resolver?.setAccountId(aliyunDNSAccountId, andAccessKeyId: aliyunDNSAccessKeyId, andAccesskeySecret: aliyunDNSAccesskeySecret)
        resolver?.cacheEnable = true
        resolver?.scheme = []
        resolver?.clearHostCache([])
        resolver?.getIpv6Data(withDomain: ali_httpdns_test_domain) { arr in
            debugPrint("Resolver DNS = \(arr ?? [])")
        }
    }
    
    /// 腾讯 DoH AAAA
    func tencentDoHAAAA() async throws -> [String] {
        var lastError: Error = DoHError.emptyAnswer

        for baseURL in tencentURl {
            do {

                let result = try await ApiRequest.rx
                    .request(.tencentDoHAAAA(baseurl: baseURL))
                    .map { try $0.filterSuccessfulStatusCodes().mapObject(DoHResponse.self) }
                    .value

                guard result.status == nil || result.status == 0 else {
                    throw DoHError.invalidResponse
                }

                let addresses = result.answers?
                    .map(\.data)
                    .filter { !$0.isEmpty } ?? []

                guard !addresses.isEmpty else {
                    throw DoHError.emptyAnswer
                }

                return addresses
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    /// Cloudflare DoH TXT 解析
    func cloudflareDoHTXT() {
        ApiRequest.rx.request(.cloudflareDoHTXT).asObservable().mapObject(DoHResponse.self).subscribe { res in
            debugPrint(res)
        }
        .disposed(by: disposeBag)
    }

}
