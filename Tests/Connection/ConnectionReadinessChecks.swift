import Foundation

// 编译真实连接协调器，只替换 Socket SDK 和导航存储边界，不访问网络。
struct OSSIMTCPNode: Equatable { let host: String; let port: UInt16 }
struct OSSConnectionPlan { let lastLiceseId: String; let apiHost: URL; let tcpCandidates: [OSSIMTCPNode] }
enum AccountLoginError: Error { case connectionChanged }
enum FixtureError: Error { case assertion(String) }
@MainActor final class OSSNavigationStore {
    static let shared = OSSNavigationStore()
    var license: String?
    func lastUsableLiceseId() -> String? { license }
    func markLastUsableEntry(lastLiceseId: String) throws { license = lastLiceseId }
    func save(_ winner: TestWinner, lastLiceseId: String) throws {}
}
@MainActor final class OSSConnectionBootstrap {
    static let shared = OSSConnectionBootstrap()
    var plan = OSSConnectionPlan(lastLiceseId: "fixture", apiHost: URL(string: "https://example.invalid")!,
                                  tcpCandidates: [OSSIMTCPNode(host: "example.invalid", port: 9000)])
    func prepare(requireFresh: Bool, probedTCPAddress: String? = nil) throws -> OSSConnectionPlan { plan }
}
struct TestWinner { let node = TestNode() }
struct TestNode { let urlString = "example.invalid:9000" }
@MainActor enum OSSNodeRaceCoordinator {
    static var cacheRequests: [Bool] = []
    static var refreshes = 0
    static func race(lastLiceseId: String, useDNS1Cache: Bool = false) async throws -> TestWinner {
        cacheRequests.append(useDNS1Cache)
        if !useDNS1Cache { refreshes += 1 }
        return TestWinner()
    }
}
@MainActor final class FakeConnectionDriver: IMSDKConnectionDriving {
    var isConnected = false
    var appliedTenantCodes: [String] = []
    func applyTenantCode(_ value: String) { appliedTenantCodes.append(value) }
    var connects = 0
    var completeHandshake = true
    var failNextConnect = false
    var afterConnect: () -> Void = {}
    func reset() { isConnected = false }
    func connect(_ plan: OSSConnectionPlan) async throws -> OSSIMTCPNode {
        connects += 1
        if failNextConnect {
            failNextConnect = false
            throw IMConnectionError.connectionLost
        }
        isConnected = completeHandshake
        afterConnect()
        return plan.tcpCandidates[0]
    }
}
typealias IMSDKConnectionAdapter = FakeConnectionDriver

@main struct ConnectionReadinessChecks {
    @MainActor static func main() async {
        do {
            try await run()
            print("PASS: local tenantCode, disconnected socket, stale attempt, AUTH ownership, cached/fresh reconnect and changed invitation")
        } catch { print("FAIL: \(error)"); exit(1) }
    }
    static func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
        if !value() { throw FixtureError.assertion(message) }
    }
    @MainActor static func run() async throws {
        let driver = FakeConnectionDriver()
        var saved: [String] = []
        let coordinator = IMConnectionCoordinator(driver: driver,
            markUsable: { saved.append($0) })
        let plan = OSSConnectionBootstrap.shared.plan
        try await coordinator.connectForLogin(plan: plan)
        try require(coordinator.isLoginReady && saved == [plan.lastLiceseId], "Handshake and local tenantCode must prepare login without any system configuration")
        try require(driver.appliedTenantCodes == ["7196295bwauak41g"], "SDK must receive tenantCode before login becomes ready")
        let firstID = coordinator.loginConnectionID!
        try coordinator.beginUserAuthentication(connectionID: firstID)
        try require(!coordinator.isLoginReady && coordinator.isUserConnectionCurrent(firstID), "AUTH must own the connection")
        coordinator.reset()
        try require(!coordinator.isLoginReady && !coordinator.isUserConnectionCurrent(firstID), "Reset must invalidate old login")

        driver.completeHandshake = false
        do { try await coordinator.connectForLogin(plan: plan); throw FixtureError.assertion("Disconnected socket became ready") }
        catch IMConnectionError.connectionLost {}
        try require(saved.count == 1, "Failed connection must not save entry")
        driver.completeHandshake = true
        driver.afterConnect = { coordinator.reset() }
        do { try await coordinator.connectForLogin(plan: plan); throw FixtureError.assertion("Stale connection became ready") }
        catch is CancellationError {}
        try require(saved.count == 1 && !coordinator.isLoginReady, "Stale connection must not publish readiness")
        driver.afterConnect = {}

        OSSNavigationStore.shared.license = plan.lastLiceseId
        coordinator.startCachedReconnect()
        for _ in 0..<100 where !coordinator.isLoginReady {
            try await Task<Never, Never>.sleep(nanoseconds: 1_000_000)
        }
        try require(coordinator.isLoginReady && saved.count == 2, "Cached reconnect must use local tenantCode without configuration")
        coordinator.reset()
        try require(driver.appliedTenantCodes == Array(repeating: "7196295bwauak41g", count: 2),
                    "Initial connection and cached reconnect must use the same fixed tenantCode")
        let otherPlan = OSSConnectionPlan(lastLiceseId: "another-club", apiHost: URL(string: "https://other.example.invalid")!,
                                          tcpCandidates: plan.tcpCandidates)
        try await coordinator.connectForLogin(plan: otherPlan)
        try require(coordinator.isLoginReady && saved.last == "another-club"
                    && driver.appliedTenantCodes == Array(repeating: "7196295bwauak41g", count: 3),
                    "Changing invitation must not change local tenantCode")
        coordinator.reset()
        // A failed cached socket must refresh server discovery and become ready
        // again without any public-IP service or remote account configuration.
        let previousRefreshes = OSSNodeRaceCoordinator.refreshes
        let previousConnects = driver.connects
        driver.failNextConnect = true
        coordinator.startCachedReconnect()
        for _ in 0..<300 where !coordinator.isLoginReady {
            try await Task<Never, Never>.sleep(nanoseconds: 10_000_000)
        }
        try require(coordinator.isLoginReady && driver.connects == previousConnects + 2,
                    "Failed cached socket must recover through fresh navigation")
        try require(OSSNodeRaceCoordinator.refreshes == previousRefreshes + 1,
                    "Reconnect must refresh server discovery after cache failure")
        try require(OSSNodeRaceCoordinator.cacheRequests.suffix(2) == [true, false], "Reconnect must try DNS1 cache then request fresh DNS1")
        try require(driver.appliedTenantCodes.last == LocalSDKSettings.tenantCode,
                    "Fresh navigation must still apply the local tenant before login")
        coordinator.reset()
    }
}
