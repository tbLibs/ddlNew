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
    case missingDecryptionKey
    case timeout
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
                    .filterSuccessfulStatusCodes()
                    .mapObject(DoHResponse.self)
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

    /// 阿里 DoH TXT 解析，按原项目的主备地址顺序获取 OSS 节点。
    /// - Parameter aesSecret: TXT 解密密钥；不传时使用 Const.swift 中的配置。
    func aliDoHTXT() async throws -> [AliDoHHost] {

        let timestamp = String(Int(Date().timeIntervalSince1970))
        let signature = AliDoHTXTDecoder.signature(timestamp: timestamp)
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        var lastError: Error = DoHError.emptyAnswer

        for baseURLString in aliDoHBaseURLs {
            try _Concurrency.Task<Never, Never>.checkCancellation()
            guard let baseURL = URL(string: baseURLString) else {
                lastError = DoHError.invalidURL
                continue
            }

            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw DoHError.timeout }

            do {
                let response = try await ApiRequest.rx
                    .request(.aliDoHTXT(baseURL: baseURL, timestamp: timestamp, signature: signature))
                    .timeout(
                        .milliseconds(max(1, Int(remaining * 1_000))),
                        scheduler: ConcurrentDispatchQueueScheduler(qos: .utility)
                    )
                    .filterSuccessfulStatusCodes()
                    .mapObject(DoHResponse.self)
                    .value

                guard response.status == nil || response.status == 0 else {
                    throw DoHError.invalidResponse
                }

                let hosts = AliDoHTXTDecoder.decode(
                    answers: response.answers ?? [],
                    aesSecret: zDNSTXTAESSecret
                )
                guard !hosts.isEmpty else { throw DoHError.emptyAnswer }
                return hosts
            } catch is CancellationError {
                throw CancellationError()
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
    
    /// CloudflareDoHAAAA 解析
    func cloudflareDoHAAAA() {
        ApiRequest.rx.request(.cloudflareAAAA).asObservable().mapObject(DoHResponse.self).subscribe { res in
            debugPrint(res)
        }
        .disposed(by: disposeBag)
    }

}
