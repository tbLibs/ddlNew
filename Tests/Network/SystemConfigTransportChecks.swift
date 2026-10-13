import Foundation
import ObjectMapper

// 这里只替代传输和磁盘边界，生产配置服务及 ObjectMapper 映射原样执行。
struct OSSConnectionPlan { let apiHost: URL; let lastLiceseId: String }
@MainActor final class OSSConnectionBootstrap {
    static let shared = OSSConnectionBootstrap()
    var current: OSSConnectionPlan?
}
@MainActor final class SystemConfigStore {
    static let shared = SystemConfigStore()
    var saved: [SystemConfigRecord] = []
    func save(_ config: SystemConfigRecord, lastLiceseId: String, apiHost: URL) throws { saved.append(config) }
}
@MainActor final class SDKSessionMaintenanceClient {
    static let json = "{\"tenantCode\":\"mock-tenant\",\"loginMethod\":\"1\",\"captchaChannel\":1}"
    static var calls = 0
    static var suspendNext = false
    static var pending: CheckedContinuation<String, Error>?
    static var loggedIn: Bool?
    func configuration(host: URL, loggedIn: Bool) async throws -> String {
        Self.calls += 1; Self.loggedIn = loggedIn
        if Self.suspendNext { Self.suspendNext = false; return try await withCheckedThrowingContinuation { Self.pending = $0 } }
        return Self.json
    }
}
enum ApiType { case systemConfig(baseURL: URL, headers: [String: String]) }
struct MockHTTPResponse {
    func mapObject<T: Mappable>(_ type: T.Type) throws -> T { Mapper<T>().map(JSON: ["code": 10000])! }
    func mapJSON() throws -> Any { ["data": ["tenantCode": "mock-tenant"]] }
}
struct MockHTTPChain {
    func request(_ type: ApiType) -> Self { self }
    func filterSuccessfulStatusCodes() -> Self { self }
    var value: MockHTTPResponse { get async throws { throw URLError(.timedOut) } }
}
enum BusinessApiRequest { static func provider(for host: URL) -> (rx: MockHTTPChain, marker: Int) { (MockHTTPChain(), 0) } }
enum BusinessRequestHeaders { static func make(timestamp: Int64, signature: String) -> [String: String] { [:] } }
enum SystemConfigCrypto {
    static func signature(timestamp: Int64) throws -> String { "anonymous-signature" }
    static func configurationDictionary(from payload: Any) throws -> [String: Any] { payload as? [String: Any] ?? [:] }
}

@main struct SystemConfigTransportChecks {
    /// HTTP 不可达但 SDK 配置通道可用时，启动不能继续被独立 HTTP 阻断。
    @MainActor static func main() async throws {
        let plan = OSSConnectionPlan(apiHost: URL(string: "https://example.invalid")!, lastLiceseId: "club")
        OSSConnectionBootstrap.shared.current = plan
        do { _ = try await SystemConfigService.shared.fetchAndCache(for: plan) }
        catch { fatalError("ECDH后的系统配置应复用可用SDK通道，不应被独立HTTP超时阻断") }
        precondition(SDKSessionMaintenanceClient.calls == 1 && SDKSessionMaintenanceClient.loggedIn == false && SystemConfigStore.shared.saved.count == 1)
        SDKSessionMaintenanceClient.suspendNext = true
        let old = Task { try await SystemConfigService.shared.fetchAndCache(for: plan) }
        while SDKSessionMaintenanceClient.pending == nil { await Task.yield() }
        _ = try await SystemConfigService.shared.fetchAndCache(for: plan)
        let prior = SystemConfigStore.shared.saved.count
        SDKSessionMaintenanceClient.pending?.resume(returning: SDKSessionMaintenanceClient.json); SDKSessionMaintenanceClient.pending = nil
        do { _ = try await old.value; fatalError("相同入口的新请求已完成，旧响应不能再写缓存") }
        catch { precondition(SystemConfigStore.shared.saved.count == prior) }
        SDKSessionMaintenanceClient.suspendNext = true
        let cancelled = Task { try await SystemConfigService.shared.fetchAndCache(for: plan) }
        while SDKSessionMaintenanceClient.pending == nil { await Task.yield() }
        cancelled.cancel()
        SDKSessionMaintenanceClient.pending?.resume(returning: SDKSessionMaintenanceClient.json); SDKSessionMaintenanceClient.pending = nil
        do { _ = try await cancelled.value; fatalError("取消的配置请求不能成功") }
        catch { precondition(SystemConfigStore.shared.saved.count == prior) }
        print("System config transport checks: 3 passed")
    }
}
