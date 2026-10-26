import Foundation
import ObjectMapper

// 仅替代网络 SDK 边界；节点解析、Protobuf 模型、ObjectMapper 缓存和连接准备执行生产代码。
nonisolated let dns1MainDomain = "main.example"
nonisolated let dns1BackupDomain = "backup.example"
nonisolated let dns1BinURLTemplate = "https://bin.example/nav_%s/npoint.bin"
nonisolated let dns1AccountId = "mock"
nonisolated let dns1AccessKey = "mock"
nonisolated let dns1AccessKeySecret = "mock"
nonisolated let dns1NavigationCacheKey = "test.dns1." + UUID().uuidString
nonisolated let ossNavigationAppStorageKey = "test.legacy." + UUID().uuidString
nonisolated let ossSelectedHTTPHostAppStorageKey = "test.http." + UUID().uuidString
@MainActor enum DNS1DoHClient {
    static var answers: [String] = []
    static var queried: [String] = []
    static func records(domain: String) async throws -> [String] {
        queried.append(domain)
        return answers
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
        let keys = [dns1NavigationCacheKey, ossNavigationAppStorageKey, ossSelectedHTTPHostAppStorageKey]
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
        DNS1DoHClient.answers = encode("node.example:2028,[::1]:2028")
        let winner = try await DNS1NodeRaceCoordinator.race(license: "Ab1000")
        check(DNS1DoHClient.queried == ["tab1000.main.example"], "生产入口只查t")
        check(winner.navigation.tcpEndpoints.count == 2 && winner.navigation.httpEndpoints.isEmpty, "真实映射接受纯TCP")
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
        check(OSSNavigationStore.shared.lastUsableLiceseId() == "Ab1000", "正式握手成功后保存入口")
        do { try OSSNavigationStore.shared.markLastUsableEntry(lastLiceseId: "other"); fatalError("跨企业标记应失败") } catch { count += 1 }
        // 升级只恢复旧入口邀请码；即使旧缓存有节点，也必须重新请求 t 域。
        let currentJSON = UserDefaults.standard.string(forKey: dns1NavigationCacheKey)!
        UserDefaults.standard.set(currentJSON, forKey: ossNavigationAppStorageKey)
        UserDefaults.standard.removeObject(forKey: dns1NavigationCacheKey)
        check(OSSNavigationStore.shared.lastUsableLiceseId() == "Ab1000", "升级保留旧成功入口")
        DNS1DoHClient.queried = []
        _ = try await DNS1NodeRaceCoordinator.race(license: "Ab1000", useCache: true)
        check(DNS1DoHClient.queried == ["tab1000.main.example"], "升级不能把旧缓存当成新节点")
        try OSSNavigationStore.shared.clearLastUsableEntry()
        check(OSSNavigationStore.shared.lastUsableLiceseId() == nil, "首次迁移前换企业也应撤销旧入口")
        UserDefaults.standard.set(currentJSON, forKey: dns1NavigationCacheKey)
        let restored = try OSSNavigationStore.shared.load()!
        check(restored.tcpEndpoints == snapshot.tcpEndpoints, "真实ObjectMapper往返节点不丢失")
        DNS1DoHClient.queried = []
        _ = try await DNS1NodeRaceCoordinator.race(license: "Ab1000", useCache: true)
        check(DNS1DoHClient.queried.isEmpty, "同企业新缓存走ECDH不查询DNS")
        _ = try await DNS1NodeRaceCoordinator.race(license: "Other", useCache: true)
        check(DNS1DoHClient.queried == ["tother.main.example"], "另一企业不可用旧缓存")
        DNS1DoHClient.answers = encode("{\"tcp\":[\"new.example:123\"],\"http\":[\"http://files.example/base\"]}")
        let withHTTP = try await DNS1NodeRaceCoordinator.race(license: "Ab1000")
        try OSSNavigationStore.shared.save(withHTTP, lastLiceseId: "Ab1000")
        let httpPlan = try OSSConnectionBootstrap.shared.prepare(requireFresh: false)
        check(httpPlan.apiHost?.absoluteString == "http://files.example/base", "可选HTTP协议及路径持久化保留")
        check(httpPlan.uploadFileHost?.absoluteString == "http://files.example/base/oss", "上传基础路径")
        var oldBody = snapshot.body; oldBody.meta.navVersion = "old-nav"
        do { _ = try OSSAuthResponseDecoder.navigation(from: oldBody); fatalError("旧协议仍需HTTP") } catch { count += 1 }
        var staleBody = snapshot.body; staleBody.meta.navVersion = "DNS1:v2:old-config"
        let staleWinner = OSSRaceWinner(source: .dns1, node: winner.node,
            navigation: OSSNavigationResult(body: staleBody, tcpEndpoints: snapshot.tcpEndpoints, httpEndpoints: []))
        do { try OSSNavigationStore.shared.save(staleWinner, lastLiceseId: "Ab1000"); fatalError("旧配置命名空间应拒绝") } catch { count += 1 }
        // 换企业撤销两个版本入口，随后重启不能恢复已撤销的旧企业。
        try OSSNavigationStore.shared.clearLastUsableEntry()
        check(OSSNavigationStore.shared.lastUsableLiceseId() == nil, "更换企业清入口")
        print("DNS1 integration checks: \(count) passed")
    }
}
