//
//  HostNodeRaceManager.swift
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//

import Foundation
import Moya
import RxMoya
import RxSwift

/// 管理五路 DNS 数据获取；最终 OSS Auth 胜出由 OSSNodeRaceCoordinator 判断。
class HostNodeRaceManager {

    private init() {}
    /// 供页面与竞速协调器复用的无状态实例。
    static let shared = HostNodeRaceManager()
    
    /// 五路 DNS 并发解析；每一路有结果时将归一化后的节点回传。
    /// 此阶段不会按 DNS 返回先后选出最终 OSS 节点。
    func getHostAndPort(onNormalized: @escaping (DNSHostSource, [DNSResolvedHost]) -> Void = { _, _ in }) {
        // SDK 使用回调，转成 Swift 任务后与其他四路共用归一化入口。
        aliAAATest { hosts in
            _Concurrency.Task {
                debugPrint("[DNS节点] aliAAATest=\(hosts)")
                await self.consume(hosts, from: .aliAAAA, onNormalized: onNormalized)
            }
        }

        // 显式使用 Swift 的 Task，避免与 Moya.Task 同名冲突。
        _Concurrency.Task {
            let hosts = try? await tencentDoHAAAA()
            debugPrint("[DNS节点] tencentDoHAAAA=\(hosts ?? [])")
            await consume(hosts ?? [], from: .tencentAAAA, onNormalized: onNormalized)
        }

        _Concurrency.Task {
            let hosts = try? await cloudflareDoHTXT()
            debugPrint("[DNS节点] cloudflareDoHTXT=\(hosts ?? [])")
            await consume(hosts ?? [], from: .cloudflareTXT, onNormalized: onNormalized)
        }
        _Concurrency.Task {
            let hosts = try? await cloudflareDoHAAAA()
            debugPrint("[DNS节点] cloudflareDoHAAAA=\(hosts ?? [])")
            await consume(hosts ?? [], from: .cloudflareAAAA, onNormalized: onNormalized)
        }
        _Concurrency.Task {
            let hosts = try? await aliDoHTXT()
            debugPrint("[DNS节点] aliDoHTXT=\(hosts ?? [])")
            await consume(hosts ?? [], from: .aliTXT, onNormalized: onNormalized)
        }
    }

    /// 空结果不参与后续流程；有结果时先归一化，再交给调用方。
    private func consume(
        _ hosts: [DNSResolvedHost],
        from source: DNSHostSource,
        onNormalized: (DNSHostSource, [DNSResolvedHost]) -> Void
    ) async {
        guard !hosts.isEmpty else { return }
        let normalized = await DNSHostNormalizer.normalize(hosts)
        guard !normalized.isEmpty else { return }
        debugPrint("[DNS节点] \(source.rawValue) 归一化结果：", normalized)
        onNormalized(source, normalized)
    }

}

extension HostNodeRaceManager {
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
        // DNSResolverSchemeHttp 的原始值为 0，Swift OptionSet 用 [] 表示。
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
        // 主、备地址顺序尝试，但共同受 5 秒总时限约束。
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
