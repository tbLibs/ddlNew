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

    private init() {}
    static let shared = HostNodeRaceManager()
    
    /// 获取【DNS节点】
    func getHostAndPort() {
        aliAAATest { hosts in
            debugPrint("[DNS节点] 阿里AAAA DNS 节点：", hosts)
        }

        _Concurrency.Task {
            let arr = try? await tencentDoHAAAA()
            debugPrint("[DNS节点] 腾讯AAAA DNS节点:", arr ?? [])
        }
        
        _Concurrency.Task {
            let hosts = try? await cloudflareDoHTXT()
            debugPrint("[DNS节点] Cloudflare TXT 节点：", hosts ?? [])
        }
        _Concurrency.Task {
            let hosts = try? await cloudflareDoHAAAA()
            debugPrint("[DNS节点] Cloudflare AAAA 节点：", hosts ?? [])
        }
        _Concurrency.Task {
            let arr = try? await aliDoHTXT()
            debugPrint("[DNS节点] aliDoHTXT DNS节点:", arr ?? [])
        }
    }


    /// 阿里 DNSResolver 的 AAAA 记录中包含分片编码的节点 JSON。
    func aliAAATest(completion: @escaping ([DNSResolvedHost]) -> Void) {
        guard let resolver = DNSResolver.share() else {
            completion([])
            return
        }

        resolver.setAccountId(
            aliyunDNSAccountId,
            andAccessKeyId: aliyunDNSAccessKeyId,
            andAccesskeySecret: aliyunDNSAccesskeySecret
        )
        resolver.cacheEnable = false
        resolver.scheme = []
        resolver.clearHostCache([])
        resolver.getIpv6Data(withDomain: ali_httpdns_test_domain) { records in
            DispatchQueue.main.async {
                completion(DNSPayloadDecoder.hosts(fromEncodedIPv6: records ?? []))
            }
        }
    }
    
    /// 腾讯 DoH AAAA
    func tencentDoHAAAA() async throws -> [DNSResolvedHost] {
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        var lastError: Error = DoHError.emptyAnswer

        for baseURL in tencentURl {
            try _Concurrency.Task<Never, Never>.checkCancellation()
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw DoHError.timeout }

            do {
                let result = try await ApiRequest.rx
                    .request(.tencentDoHAAAA(baseurl: baseURL))
                    .timeout(
                        .milliseconds(max(1, Int(remaining * 1_000))),
                        scheduler: ConcurrentDispatchQueueScheduler(qos: .utility)
                    )
                    .filterSuccessfulStatusCodes()
                    .mapObject(DoHResponse.self)
                    .value

                guard result.status == nil || result.status == 0 else {
                    throw DoHError.invalidResponse
                }

                let hosts = DNSPayloadDecoder.hosts(
                    fromEncodedIPv6: result.answers?.map(\.data) ?? []
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

    /// Cloudflare DoH TXT 解析。
    func cloudflareDoHTXT() async throws -> [DNSResolvedHost] {
        let response = try await ApiRequest.rx
            .request(.cloudflareDoHTXT)
            .timeout(.seconds(5), scheduler: ConcurrentDispatchQueueScheduler(qos: .utility))
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
    }
    
    /// Cloudflare DoH AAAA 解析。
    func cloudflareDoHAAAA() async throws -> [DNSResolvedHost] {
        let response = try await ApiRequest.rx
            .request(.cloudflareAAAA)
            .timeout(.seconds(5), scheduler: ConcurrentDispatchQueueScheduler(qos: .utility))
            .filterSuccessfulStatusCodes()
            .mapObject(DoHResponse.self)
            .value

        guard response.status == nil || response.status == 0 else {
            throw DoHError.invalidResponse
        }

        let hosts = DNSPayloadDecoder.hosts(
            fromEncodedIPv6: response.answers?.map(\.data) ?? []
        )
        guard !hosts.isEmpty else { throw DoHError.emptyAnswer }
        return hosts
    }

}
