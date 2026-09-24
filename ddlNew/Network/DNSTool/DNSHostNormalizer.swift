//
//  DNSHostNormalizer.swift
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//

import Foundation
import Darwin
import Moya
import RxMoya
import RxSwift

/// 对五路 DNS 返回的 OSS 地址执行与旧项目相同的 IP、端口归一化。
enum DNSHostNormalizer {
    /// 与旧项目一致，每个域名的 A 记录竞速最多等待约 500 毫秒。
    private static let lookupTimeout = 0.5

    /// 保持输入顺序，按 IP:端口去重；首个结果沿用原类型，其余标记为备用节点。
    static func normalize(_ list: [DNSResolvedHost]) async -> [DNSResolvedHost] {
        var result: [DNSResolvedHost] = []
        var seen = Set<String>()

        for item in list {
            if _Concurrency.Task<Never, Never>.isCancelled { break }
            guard let parsed = parseAddress(item.urlString) else { continue }

            let addresses: [String]
            if isIPAddress(parsed.host) {
                // 已是 IPv4/IPv6 时不再发起 A 记录查询。
                addresses = [parsed.host]
            } else {
                let ips = await resolveA(parsed.host)
                // 旧项目在 A 记录全部失败时会保留原域名。
                addresses = ips.isEmpty ? [parsed.host] : ips
            }

            for host in addresses {
                let value: String
                if let port = parsed.port {
                    // IPv6 带端口时必须用方括号，避免与地址中的冒号混淆。
                    value = isIPv6(host) ? "[\(host)]:\(port)" : "\(host):\(port)"
                } else {
                    value = host
                }
                guard seen.insert(value).inserted else { continue }
                result.append(DNSResolvedHost(
                    urlString: value,
                    type: result.isEmpty ? item.type : "2"
                ))
            }
        }

        return result
    }

    private static func parseAddress(_ address: String) -> (host: String, port: UInt16?)? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var host = trimmed
        var rawPort: String?
        // 分别识别 [IPv6]:port 和只有一个冒号的 host:port；裸 IPv6 不拆端口。
        if trimmed.hasPrefix("["), let closing = trimmed.firstIndex(of: "]") {
            host = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closing])
            let suffix = trimmed[trimmed.index(after: closing)...]
            if suffix.hasPrefix(":") { rawPort = String(suffix.dropFirst()) }
        } else if trimmed.filter({ $0 == ":" }).count == 1 {
            let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
            if parts.count == 2 {
                host = String(parts[0])
                rawPort = String(parts[1])
            }
        }

        host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return nil }
        // 无效端口按旧项目处理为“无端口”，但仍保留主机。
        let port = rawPort.flatMap { UInt16($0) }.flatMap { $0 > 0 ? $0 : nil }
        return (host, port)
    }

    private static func isIPAddress(_ host: String) -> Bool {
        var ipv4 = in_addr()
        var ipv6 = in6_addr()
        return inet_pton(AF_INET, host, &ipv4) == 1 || inet_pton(AF_INET6, host, &ipv6) == 1
    }

    private static func isIPv6(_ host: String) -> Bool {
        var ipv6 = in6_addr()
        return inet_pton(AF_INET6, host, &ipv6) == 1
    }

    private enum LookupResult: Sendable {
        case addresses([String])
        case timeout
    }

    /// 阿里 DoH、Cloudflare DoH 和两个 UDP DNS 同时查询，最先得到有效 A 记录者胜出。
    private static func resolveA(_ domain: String) async -> [String] {
        await withTaskGroup(of: LookupResult.self) { group in
            group.addTask { .addresses(await resolveAliA(domain)) }
            group.addTask { .addresses(await requestA(.cloudflareA(domain: domain))) }
            for server in dnsARecordServers {
                group.addTask {
                    .addresses(await DNSUDPResolver.resolveA(domain: domain, server: server))
                }
            }
            // 单独放入超时任务，使慢请求不会无限期阻塞域名归一化。
            group.addTask {
                try? await _Concurrency.Task<Never, Never>.sleep(
                    nanoseconds: UInt64(lookupTimeout * 1_000_000_000)
                )
                return .timeout
            }

            for await outcome in group {
                switch outcome {
                case .addresses(let ips) where !ips.isEmpty:
                    // 只使用最先成功的解析源，不混合不同 DNS 源的结果。
                    group.cancelAll()
                    return ips
                case .timeout:
                    group.cancelAll()
                    return []
                case .addresses:
                    break
                }
            }
            return []
        }
    }

    private static func resolveAliA(_ domain: String) async -> [String] {
        // 阿里主、备地址按顺序尝试；成功后不再请求后续地址。
        for address in aliARecordBaseURLs {
            if _Concurrency.Task<Never, Never>.isCancelled { return [] }
            guard let baseURL = URL(string: address) else { continue }
            let ips = await requestA(.aliDoHA(baseURL: baseURL, domain: domain))
            if !ips.isEmpty { return ips }
        }
        return []
    }

    private static func requestA(_ target: ApiType) async -> [String] {
        do {
            let response = try await ApiRequest.rx
                .request(target)
                .timeout(.milliseconds(Int(lookupTimeout * 1_000)),
                         scheduler: ConcurrentDispatchQueueScheduler(qos: .utility))
                .filterSuccessfulStatusCodes()
                .mapObject(DoHResponse.self)
                .value
            guard response.status == nil || response.status == 0 else { return [] }
            // DoH 的 Answer 可能含 CNAME 等记录，只接受合法的 IPv4 A 记录。
            return response.answers?.compactMap { answer in
                guard answer.type == 1 else { return nil }
                var address = in_addr()
                return inet_pton(AF_INET, answer.data, &address) == 1 ? answer.data : nil
            } ?? []
        } catch {
            return []
        }
    }
}
