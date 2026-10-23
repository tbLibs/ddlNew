//
//  DNS1FallbackChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/22.
//

import Foundation

// 执行真实统一入口与五路任务组，只替代 DNS、网络运输和缓存边界。
nonisolated let dns1NavigationEnabled = true
nonisolated let ali_httpdns_test_domain = "legacy.example"
nonisolated let legacyNavigationDomain = "resolver.example"
nonisolated let builtInNavigationDomesticAddresses = ["builtin.example:80"]
nonisolated let builtInNavigationOverseasAddresses: [String] = []
nonisolated struct DNSResolvedHost: Sendable { let urlString: String; let type: String }
nonisolated struct OSSNavigationResult: Sendable { let marker: String }
enum DNS1Error: Error { case unavailable, invalidLicense }
@MainActor enum Boundary {
    static var nativeFails = true
    static var nativeCancelled = false
    static var nativeInvalid = false
    static var legacySucceeds = true
    static var calls: [String] = []
    static func reset() { calls = []; nativeFails = true; nativeCancelled = false; nativeInvalid = false; legacySucceeds = true }
}
@MainActor enum DNS1NodeRaceCoordinator {
    static func race(license: String, useCache: Bool = false) async throws -> OSSRaceWinner {
        Boundary.calls.append(useCache ? "DNS1-cache" : "DNS1")
        if Boundary.nativeCancelled { throw CancellationError() }
        if Boundary.nativeInvalid { throw DNS1Error.invalidLicense }
        if Boundary.nativeFails { throw DNS1Error.unavailable }
        return OSSRaceWinner(source: .dns1, node: DNSResolvedHost(urlString: "native.example:443", type: "DNS1"), navigation: OSSNavigationResult(marker: "native"))
    }
}
@MainActor final class HostNodeRaceManager {
    static let shared = HostNodeRaceManager()
    func nodes(_ source: DNSHostSource) -> [DNSResolvedHost] {
        Boundary.calls.append(source.rawValue)
        return [DNSResolvedHost(urlString: source.rawValue, type: "5")]
    }
    func aliAAATest(domain: String, completion: ([DNSResolvedHost]) -> Void) { completion(nodes(domain == ali_httpdns_test_domain ? .aliAAAA : .oldResolver)) }
    func tencentDoHAAAA() async throws -> [DNSResolvedHost] { nodes(.tencentAAAA) }
    func cloudflareDoHTXT() async throws -> [DNSResolvedHost] { nodes(.cloudflareTXT) }
    func cloudflareDoHAAAA() async throws -> [DNSResolvedHost] { nodes(.cloudflareAAAA) }
    func aliDoHTXT() async throws -> [DNSResolvedHost] { nodes(.aliTXT) }
}
@MainActor enum DNSHostNormalizer { static func normalize(_ nodes: [DNSResolvedHost]) async -> [DNSResolvedHost] { nodes } }
@MainActor enum OSSAuthRequestBuilder {
    static func make(lastLiceseId: String, signingKeyID: String, signingKeySecret: String, clientIP: String) throws -> String { lastLiceseId }
}
@MainActor enum OSSAuthTCPClient {
    static func request(_ request: String, to node: DNSResolvedHost) async throws -> String {
        // 留出任务组启动全部五路的时间；第五路胜出，验证并非只接了单一旧源。
        try await Task<Never, Never>.sleep(nanoseconds: 2_000_000)
        guard Boundary.legacySucceeds, node.urlString == DNSHostSource.aliTXT.rawValue else { throw DNS1Error.unavailable }
        return node.urlString
    }
}
@MainActor enum OSSAuthResponseDecoder {
    static func decode(_ response: String, lastLiceseId: String) throws -> OSSNavigationResult { OSSNavigationResult(marker: response) }
}
@MainActor enum OSSHTTPConfigurationClient {
    static func race(lastLiceseId: String) async throws -> OSSRaceWinner { Boundary.calls.append("HTTP"); throw DNS1Error.unavailable }
}
@MainActor final class OSSNavigationStore {
    struct Snapshot { let fallbackEndpoints: Fallback }
    struct Fallback { let domestic: [String]; let overseas: [String] }
    static let shared = OSSNavigationStore()
    func load() throws -> Snapshot? { nil }
}
@main struct DNS1FallbackChecks {
    @MainActor static func main() async throws {
        let credentials = OSSAuthCredentials(signingKeyID: "fixture", signingKeySecret: "fixture")
        let winner = try await OSSNodeRaceCoordinator.race(lastLiceseId: "fixture", credentials: credentials)
        precondition(winner.source == .aliTXT, "DNS1 全失败必须让第五路也有机会获胜")
        precondition(Boundary.calls.first == "DNS1")
        precondition(Set(Boundary.calls.dropFirst()) == Set(DNSHostSource.primarySources.map(\.rawValue)), "必须启动原五路，首胜后不运行后续兜底")
        Boundary.reset(); Boundary.nativeFails = false
        let native = try await OSSNodeRaceCoordinator.race(lastLiceseId: "fixture", credentials: credentials)
        precondition(native.source == .dns1 && Boundary.calls == ["DNS1"], "DNS1 成功不得启动五路")
        Boundary.reset(); Boundary.nativeFails = false
        _ = try await OSSNodeRaceCoordinator.race(lastLiceseId: "fixture", credentials: credentials, useDNS1Cache: true)
        precondition(Boundary.calls == ["DNS1-cache"], "冷启动参数必须传到原生缓存探测")
        Boundary.reset()
        let cancelled = Task { @MainActor in
            try await OSSNodeRaceCoordinator.race(lastLiceseId: "fixture", credentials: credentials)
        }
        cancelled.cancel()
        do { _ = try await cancelled.value; fatalError("预先取消应结束") } catch is CancellationError {}
        precondition(Boundary.calls.isEmpty, "预先取消不能启动任意来源")
        Boundary.reset(); Boundary.nativeCancelled = true
        do { _ = try await OSSNodeRaceCoordinator.race(lastLiceseId: "fixture", credentials: credentials); fatalError("取消应传播") }
        catch is CancellationError {} catch { fatalError("取消类型丢失") }
        precondition(Boundary.calls == ["DNS1"], "取消不得启动兜底")
        Boundary.reset(); Boundary.nativeInvalid = true
        do { _ = try await OSSNodeRaceCoordinator.race(lastLiceseId: "fixture", credentials: credentials); fatalError("非法输入应失败") }
        catch is DNS1Error {}
        precondition(Boundary.calls == ["DNS1"], "非法输入不得当作来源耗尽")
        Boundary.reset(); Boundary.legacySucceeds = false
        do { _ = try await OSSNodeRaceCoordinator.race(lastLiceseId: "fixture", credentials: credentials); fatalError("全部失败不得成功") } catch {}
        precondition(Boundary.calls.contains("HTTP") && Boundary.calls.filter { $0 == "DNS1" }.count == 1, "五路失败继续原兜底且不递归DNS1")
        print("DNS1 fallback checks: 10 passed")
    }
}
