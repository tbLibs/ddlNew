//
//  DNS1NodeRaceCoordinator.swift
//  ddlNew
//
//  Created by taobo on 2026/10/17.
//

import Foundation
import CryptoKit
import NoaChatCore

/// 仅在内存中转为现有连接模型，不向旧 OSS 导航发送请求，也不查询 Web 的 w 域名。
@MainActor enum DNS1NodeRaceCoordinator {
    static var version: String {
        let input = [dns1MainDomain, dns1BackupDomain, dns1BinURLTemplate].joined(separator: "|")
        let hash = SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
        return "DNS1:v2:" + hash
    }

    static func race(license: String, useCache: Bool = false) async throws -> OSSRaceWinner {
        let sources = try DNS1SourceRace.sources(license: license, main: dns1MainDomain,
            backup: dns1BackupDomain, binTemplate: dns1BinURLTemplate)
        var cached: DNS1Payload?
        if useCache, let snapshot = try? OSSNavigationStore.shared.load(), snapshot.lastLiceseId == license, snapshot.source == .dns1 {
            cached = try? payload(from: snapshot.body)
        }
        let selection = try await DNS1SourceRace.run(sources: sources, cached: cached,
            load: { try await load($0, license: license) }, probe: probe)
        try Task.checkCancellation()
        let body = try body(selection.payload, selected: selection.node)
        let navigation = try OSSAuthResponseDecoder.navigation(from: body)
        return OSSRaceWinner(source: .dns1, node: DNSResolvedHost(urlString: selection.node.address, type: "DNS1"), navigation: navigation)
    }

    private static func load(_ source: DNS1Source, license: String) async throws -> DNS1Payload {
        if source.kind == .bin {
            guard let url = URL(string: source.address), url.scheme == "https" else { throw DNS1Error.invalidPayload }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 5
            configuration.timeoutIntervalForResource = 5
            configuration.urlCache = nil; configuration.httpCookieStorage = nil; configuration.urlCredentialStorage = nil
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            let (data, response) = try await session.data(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5))
            try Task.checkCancellation()
            guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 1_048_576 else { throw DNS1Error.unavailable }
            return try DNS1Payload.bin(data, license: license)
        }
        let waiter = DNS1CallbackWaiter<[String]>()
        let records = try await waiter.run(seconds: 5) {
            guard let resolver = DNSResolver.share() else { waiter.finish(.failure(DNS1Error.unavailable)); return }
            // Web accessKeyId 实际是 UID；accessKey 对应 SDK 的 AK。凭据、DNS 原文不写日志。
            resolver.setAccountId(dns1AccountId, andAccessKeyId: dns1AccessKey, andAccesskeySecret: dns1AccessKeySecret)
            resolver.cacheEnable = false
            resolver.scheme = DNSResolverScheme(rawValue: 1)
            resolver.timeout = 5
            resolver.getIpv6Data(withDomain: source.address) { records in
                let snapshot = records ?? []
                Task { @MainActor in waiter.finish(.success(snapshot)) }
            }
        }
        try Task.checkCancellation()
        return try DNS1Payload.records(records)
    }

    private static func probe(_ node: DNS1TCPNode) async throws -> Bool {
        let waiter = DNS1CallbackWaiter<Bool>()
        return try await waiter.run(seconds: 4) {
            NoaIMSDKManager.sharedTool().probeECDHConnectivity(withHost: node.host, port: node.port, timeout: 4, type: 0) { success, _ in
                Task { @MainActor in waiter.finish(.success(success)) }
            }
        }
    }

    /// 原生载荷作为独立版本写入现有持久化容器；不伪造旧导航的探测开关或 HTTP 节点。
    private static func body(_ payload: DNS1Payload, selected: DNS1TCPNode) throws -> IMServerListResponseBody {
        var body = IMServerListResponseBody()
        body.imEndpoints = ([selected] + payload.tcp.filter { $0 != selected }).map { node in
            var endpoint = IMServerEndpoint()
            endpoint.ip = node.host; endpoint.port = Int32(node.port); endpoint.protocols = ["tcp"]
            return endpoint
        }
        body.meta.navVersion = version
        // traceID 在该本地版本中专门保存可选 HTTP 元数据，保留 scheme/path，不从 TCP 猜端口。
        body.meta.traceID = String(decoding: try JSONSerialization.data(withJSONObject: payload.http.map(\.absoluteString)), as: UTF8.self)
        body.cacheTtl = 0 // 服务端未给 TTL；恢复缓存只作为候选，必须重新探测和获取系统配置。
        return body
    }

    static func payload(from body: IMServerListResponseBody) throws -> DNS1Payload {
        guard body.meta.navVersion == version,
              let urls = try JSONSerialization.jsonObject(with: Data(body.meta.traceID.utf8)) as? [String] else { throw DNS1Error.invalidPayload }
        let tcp = body.imEndpoints.filter { $0.protocols == ["tcp"] }.map {
            $0.ip.contains(":") ? "[\($0.ip)]:\($0.port)" : "\($0.ip):\($0.port)"
        }
        let json = try JSONSerialization.data(withJSONObject: ["tcp": tcp, "http": urls])
        return try DNS1Payload.decode(String(decoding: json, as: UTF8.self), requireJSON: true)
    }
}
