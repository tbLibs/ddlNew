import Foundation
import ObjectMapper

@MainActor final class CallConfigurationStore {
    static let shared = CallConfigurationStore()
    var tenants: [String] = []
    func update(json: String, tenantID: String) { tenants.append(tenantID) }
}

// 这里只替代传输和磁盘边界，生产配置服务及 ObjectMapper 映射原样执行。
struct OSSConnectionPlan { let apiHost: URL?; let lastLiceseId: String }
@MainActor final class OSSConnectionBootstrap {
    static let shared = OSSConnectionBootstrap()
    var current: OSSConnectionPlan?
}
@MainActor final class SystemConfigStore {
    static let shared = SystemConfigStore()
    var saved: [SystemConfigRecord] = []
    /// 仅收集配置写入结果，验证旧轮次和取消结果不会落盘。
    func save(_ config: SystemConfigRecord, lastLiceseId: String, apiHost: URL?) throws { saved.append(config) }
}
@MainActor final class SDKSessionMaintenanceClient {
    static let json = "{\"tenantCode\":\"mock-tenant\",\"loginMethod\":\"1\",\"captchaChannel\":1}"
    static var calls = 0
    static var suspendNext = false
    static var pending: CheckedContinuation<String, Error>?
    static var loggedIn: Bool?
    /// 传输替身可挂起旧响应，生产服务的解析和归属守卫保持原样。
    func configuration(host: URL?, loggedIn: Bool) async throws -> String {
        Self.calls += 1; Self.loggedIn = loggedIn
        if Self.suspendNext { Self.suspendNext = false; return try await withCheckedThrowingContinuation { Self.pending = $0 } }
        return Self.json
    }
}
enum ApiType { case systemConfig(baseURL: URL, headers: [String: String]) }
struct MockHTTPResponse {
    /// 保留旧HTTP响应映射形状，测试仍使用真实ObjectMapper。
    func mapObject<T: Mappable>(_ type: T.Type) throws -> T { Mapper<T>().map(JSON: ["code": 10000])! }
    /// 返回匿名响应形状，不访问真实服务端配置。
    func mapJSON() throws -> Any { ["data": ["tenantCode": "mock-tenant"]] }
}
struct MockHTTPChain {
    /// 接收旧HTTP调用参数，避免测试替身改变生产方法签名。
    func request(_ type: ApiType) -> Self { self }
    /// 保留状态码过滤链，错误由异步传输边界抛出。
    func filterSuccessfulStatusCodes() -> Self { self }
    var value: MockHTTPResponse { get async throws { throw URLError(.timedOut) } }
}
enum BusinessApiRequest {
    /// 提供始终HTTP超时的链，检验SDK通道不依赖独立HTTP可达。
    static func provider(for host: URL) -> (rx: MockHTTPChain, marker: Int) { (MockHTTPChain(), 0) }
}
enum BusinessRequestHeaders {
    /// 头部替身不生成或保存任何真实认证数据。
    static func make(timestamp: Int64, signature: String) -> [String: String] { [:] }
}
enum SystemConfigCrypto {
    /// 匿名签名只供离线接口形状使用，不调用加密库。
    static func signature(timestamp: Int64) throws -> String { "anonymous-signature" }
    /// 保留配置字典解包边界，不解密任何真实响应。
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
        precondition(CallConfigurationStore.shared.tenants == ["club"])
        SDKSessionMaintenanceClient.suspendNext = true
        let old = Task { try await SystemConfigService.shared.fetchAndCache(for: plan) }
        while SDKSessionMaintenanceClient.pending == nil { await Task.yield() }
        _ = try await SystemConfigService.shared.fetchAndCache(for: plan)
        let prior = SystemConfigStore.shared.saved.count
        SDKSessionMaintenanceClient.pending?.resume(returning: SDKSessionMaintenanceClient.json); SDKSessionMaintenanceClient.pending = nil
        do { _ = try await old.value; fatalError("相同入口的新请求已完成，旧响应不能再写缓存") }
        catch { precondition(SystemConfigStore.shared.saved.count == prior) }
        precondition(CallConfigurationStore.shared.tenants.count == prior, "旧请求不能替换通话配置")
        SDKSessionMaintenanceClient.suspendNext = true
        let cancelled = Task { try await SystemConfigService.shared.fetchAndCache(for: plan) }
        while SDKSessionMaintenanceClient.pending == nil { await Task.yield() }
        cancelled.cancel()
        SDKSessionMaintenanceClient.pending?.resume(returning: SDKSessionMaintenanceClient.json); SDKSessionMaintenanceClient.pending = nil
        do { _ = try await cancelled.value; fatalError("取消的配置请求不能成功") }
        catch { precondition(SystemConfigStore.shared.saved.count == prior) }
        precondition(CallConfigurationStore.shared.tenants.count == prior, "取消的配置不能改变通话供应商")
        let tcpOnly = OSSConnectionPlan(apiHost: nil, lastLiceseId: "native")
        OSSConnectionBootstrap.shared.current = tcpOnly
        _ = try await SystemConfigService.shared.fetchAndCache(for: tcpOnly)
        precondition(SystemConfigStore.shared.saved.count == prior + 1, "TCP-only 系统配置不能被空 HTTP 拦住")
        precondition(CallConfigurationStore.shared.tenants.last == "native")
        print("System config transport checks: 4 passed")
    }
}
