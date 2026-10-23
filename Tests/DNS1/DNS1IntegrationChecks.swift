import Foundation
import ObjectMapper

// 仅替代网络 SDK 边界；节点解析、Protobuf 模型、ObjectMapper 缓存和连接准备执行生产代码。
nonisolated let dns1NavigationEnabled = true
nonisolated let dns1MainDomain = "main.example"
nonisolated let dns1BackupDomain = "backup.example"
nonisolated let dns1BinURLTemplate = "https://bin.example/nav_%s/npoint.bin"
nonisolated let dns1AccountId = "mock"
nonisolated let dns1AccessKey = "mock"
nonisolated let dns1AccessKeySecret = "mock"
nonisolated let dns1NavigationCacheKey = "test.dns1." + UUID().uuidString
nonisolated let ossNavigationAppStorageKey = "test.legacy." + UUID().uuidString
nonisolated let ossSelectedHTTPHostAppStorageKey = "test.http." + UUID().uuidString
nonisolated let systemConfigAppStorageKey = "test.config." + UUID().uuidString
nonisolated struct DNSResolvedHost: Sendable { let urlString: String; let type: String }
nonisolated struct OSSRaceWinner: Sendable { let source: DNSHostSource; let node: DNSResolvedHost; let navigation: OSSNavigationResult }
struct DNSResolverScheme { let rawValue: Int }
@MainActor final class DNSResolver {
    static let shared = DNSResolver()
    static var records: [String] = []
    static var queried: [String] = []
    var cacheEnable = true
    var scheme = DNSResolverScheme(rawValue: 0)
    var timeout: Double = 0
    static func share() -> DNSResolver? { shared }
    func setAccountId(_ uid: String, andAccessKeyId: String, andAccesskeySecret: String) {}
    func getIpv6Data(withDomain: String, completion: ([String]?) -> Void) {
        Self.queried.append(withDomain); completion(Self.records)
    }
}
@MainActor final class NoaIMSDKManager {
    static let shared = NoaIMSDKManager()
    static func sharedTool() -> NoaIMSDKManager { shared }
    func probeECDHConnectivity(withHost: String, port: UInt16, timeout: Double, type: Int, completion: (Bool, Int) -> Void) { completion(true, 0) }
}

@main struct DNS1IntegrationChecks {
    @MainActor static func main() async throws {
        var count = 0
        func check(_ value: Bool, _ message: String) { precondition(value, message); count += 1 }
        let keys = [dns1NavigationCacheKey, ossNavigationAppStorageKey, ossSelectedHTTPHostAppStorageKey, systemConfigAppStorageKey]
        defer { keys.forEach { UserDefaults.standard.removeObject(forKey: $0) } }
        func encode(_ text: String) -> [String] {
            var bytes = Array(text.utf8); bytes.append(0)
            while bytes.count % 14 != 0 { bytes.append(0) }
            return stride(from: 0, to: bytes.count, by: 14).map { start in
                let index = 1 + start / 14
                let block = [UInt8(index >> 8), UInt8(index & 255)] + Array(bytes[start..<(start + 14)])
                return stride(from: 0, to: 16, by: 2).map { String(Int(block[$0]) * 256 + Int(block[$0 + 1]), radix: 16) }.joined(separator: ":")
            }
        }
        DNSResolver.records = encode("node.example:2028,[::1]:2028")
        let winner = try await DNS1NodeRaceCoordinator.race(license: "Ab1000")
        check(DNSResolver.queried == ["tab1000.main.example"], "生产入口只查t")
        check(winner.navigation.tcpEndpoints.count == 2 && winner.navigation.httpEndpoints.isEmpty, "真实映射接受纯TCP")
        check(DNSResolver.shared.scheme.rawValue == 1 && !DNSResolver.shared.cacheEnable, "DNS使用HTTPS禁用缓存")
        UserDefaults.standard.set("https://stale.example", forKey: ossSelectedHTTPHostAppStorageKey)
        let snapshot = try OSSNavigationStore.shared.save(winner, lastLiceseId: "Ab1000")
        let plan = try OSSConnectionBootstrap.shared.prepare(requireFresh: false)
        check(plan.probedTCPNode == nil, "落盘恢复不能继承旧探测状态")
        let selectedPlan = try OSSConnectionBootstrap.shared.prepare(requireFresh: false, probedTCPAddress: winner.node.urlString)
        check(selectedPlan.probedTCPNode != nil && selectedPlan.tcpCandidates.contains(selectedPlan.probedTCPNode!), "当前已探测节点直接交正式连接")
        check(plan.apiHost == nil && plan.getFileHost == nil && plan.uploadFileHost == nil && plan.tcpCandidates.count == 2, "TCP-only连接方案")
        check(OSSConnectionBootstrap.shared.cachedHTTPHost() == nil, "清除旧HTTP缓存")
        check(OSSNavigationStore.shared.lastUsableLiceseId() == nil, "探测成功不能提前保存启动入口")
        try OSSNavigationStore.shared.markLastUsableEntry(lastLiceseId: "Ab1000")
        check(OSSNavigationStore.shared.lastUsableLiceseId() == "Ab1000", "正式配置成功后保存入口")
        do { try OSSNavigationStore.shared.markLastUsableEntry(lastLiceseId: "other"); fatalError("跨企业标记应失败") } catch { count += 1 }
        // 升级只恢复旧入口邀请码；即使旧缓存有节点，也必须重新请求 t 域。
        let currentJSON = UserDefaults.standard.string(forKey: dns1NavigationCacheKey)!
        UserDefaults.standard.set(currentJSON, forKey: ossNavigationAppStorageKey)
        UserDefaults.standard.removeObject(forKey: dns1NavigationCacheKey)
        check(OSSNavigationStore.shared.lastUsableLiceseId() == "Ab1000", "升级保留旧成功入口")
        DNSResolver.queried = []
        _ = try await DNS1NodeRaceCoordinator.race(license: "Ab1000", useCache: true)
        check(DNSResolver.queried == ["tab1000.main.example"], "升级不能把旧缓存当成新节点")
        try OSSNavigationStore.shared.clearLastUsableEntry()
        check(OSSNavigationStore.shared.lastUsableLiceseId() == nil, "首次迁移前换企业也应撤销旧入口")
        UserDefaults.standard.set(currentJSON, forKey: dns1NavigationCacheKey)
        let restored = try OSSNavigationStore.shared.load()!
        check(restored.tcpEndpoints == snapshot.tcpEndpoints, "真实ObjectMapper往返节点不丢失")
        DNSResolver.queried = []
        _ = try await DNS1NodeRaceCoordinator.race(license: "Ab1000", useCache: true)
        check(DNSResolver.queried.isEmpty, "同企业新缓存走ECDH不查询DNS")
        _ = try await DNS1NodeRaceCoordinator.race(license: "Other", useCache: true)
        check(DNSResolver.queried == ["tother.main.example"], "另一企业不可用旧缓存")
        OSSConnectionBootstrap.shared.updateHTTPHost("https://stale.example")
        check(OSSConnectionBootstrap.shared.current?.apiHost == nil, "旧SDK回调不能添加未知HTTP")
        let config = Mapper<SystemConfigRecord>().map(JSON: ["tenantCode":"anonymous", "captchaChannel":1, "loginMethod":"1"])!
        try SystemConfigStore.shared.save(config, lastLiceseId: "Ab1000", apiHost: nil)
        check(SystemConfigStore.shared.load(apiHost: nil, lastLiceseId: "Ab1000") != nil, "空HTTP配置按企业恢复")
        check(SystemConfigStore.shared.load(apiHost: nil, lastLiceseId: "Other") == nil, "空HTTP不能跨企业复用配置")
        check(SystemConfigStore.shared.load(apiHost: nil) == nil, "空HTTP读取必须提供身份")
        DNSResolver.records = encode("{\"tcp\":[\"new.example:123\"],\"http\":[\"http://files.example/base\"]}")
        let withHTTP = try await DNS1NodeRaceCoordinator.race(license: "Ab1000")
        try OSSNavigationStore.shared.save(withHTTP, lastLiceseId: "Ab1000")
        let httpPlan = try OSSConnectionBootstrap.shared.prepare(requireFresh: false)
        check(httpPlan.apiHost?.absoluteString == "http://files.example/base", "可选HTTP协议及路径持久化保留")
        check(httpPlan.uploadFileHost?.absoluteString == "http://files.example/base/oss", "上传基础路径")
        var oldBody = snapshot.body; oldBody.meta.navVersion = "old-nav"
        do { _ = try OSSAuthResponseDecoder.navigation(from: oldBody); fatalError("旧协议仍需HTTP") } catch { count += 1 }
        // DNS1 耗尽后，五路首胜仍保存真实旧协议，不能按 DNS1 载荷重新解码。
        var legacyBody = IMServerListResponseBody()
        var tcp = IMServerEndpoint(); tcp.ip = "legacy-tcp.example"; tcp.port = 9000; tcp.protocols = ["tcp"]
        var http = IMServerEndpoint(); http.ip = "legacy-http.example"; http.port = 8443; http.protocols = ["http"]
        var http2 = http; http2.ip = "legacy-backup.example"
        legacyBody.imEndpoints = [tcp, http, http2]
        legacyBody.meta.navVersion = "legacy-nav"
        legacyBody.meta.config.enableNetworkDetect = true
        let legacyWinner = OSSRaceWinner(source: .aliTXT, node: DNSResolvedHost(urlString: "oss.example:80", type: "5"),
            navigation: try OSSAuthResponseDecoder.navigation(from: legacyBody))
        try OSSNavigationStore.shared.save(legacyWinner, lastLiceseId: "Ab1000")
        let legacyRestored = try OSSNavigationStore.shared.load()!
        check(legacyRestored.source == .aliTXT && legacyRestored.configuration?.enableNetworkDetect == true, "旧导航来源和检测开关往返保留")
        let legacyPlan = try OSSConnectionBootstrap.shared.prepare(requireFresh: false, probedTCPAddress: "legacy-tcp.example:9000")
        check(legacyPlan.apiHost?.absoluteString == "https://legacy-http.example:8443" && legacyPlan.tcpCandidates.first?.host == "legacy-tcp.example", "旧导航走原HTTP和TCP准备")
        check(legacyPlan.probedTCPNode == nil, "OSS首胜不是业务TCP握手成功")
        try OSSNavigationStore.shared.markLastUsableEntry(lastLiceseId: "Ab1000")
        check(OSSNavigationStore.shared.lastUsableLiceseId() == "Ab1000", "五路兜底成功后可恢复入口")
        DNSResolver.queried = []
        _ = try await DNS1NodeRaceCoordinator.race(license: "Ab1000", useCache: true)
        check(DNSResolver.queried == ["tab1000.main.example"], "旧导航缓存不能冒充DNS1缓存，恢复仍先查询DNS1")
        OSSConnectionBootstrap.shared.updateHTTPHost("legacy-backup.example:8443")
        check(OSSConnectionBootstrap.shared.current?.apiHost?.host == "legacy-backup.example", "五路结果允许切换当前导航HTTP")
        OSSConnectionBootstrap.shared.updateHTTPHost("https://stale.example")
        check(OSSConnectionBootstrap.shared.current?.apiHost?.host == "legacy-backup.example", "五路结果拒绝非当前导航的迟到HTTP")
        var staleBody = snapshot.body; staleBody.meta.navVersion = "DNS1:v2:old-config"
        let staleWinner = OSSRaceWinner(source: .dns1, node: winner.node,
            navigation: OSSNavigationResult(body: staleBody, tcpEndpoints: snapshot.tcpEndpoints, httpEndpoints: []))
        try OSSNavigationStore.shared.save(staleWinner, lastLiceseId: "Ab1000")
        do { _ = try OSSNavigationStore.shared.load(); fatalError("旧配置命名空间应拒绝") } catch { count += 1 }
        // 换企业撤销两个版本入口，随后重启不能恢复已撤销的旧企业。
        try OSSNavigationStore.shared.clearLastUsableEntry()
        check(OSSNavigationStore.shared.lastUsableLiceseId() == nil, "更换企业清入口")
        print("DNS1 integration checks: \(count) passed")
    }
}
