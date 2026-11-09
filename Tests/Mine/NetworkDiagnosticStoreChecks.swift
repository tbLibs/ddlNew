import Foundation

let dns1MainDomain = "test.invalid"
let dns1BackupDomain = "backup.invalid"
let dns1BinURLTemplate = "https://bin.invalid/%s"
struct ChatRoute { enum Kind { case single }; let id: String; let kind: Kind; let title: String; let avatarURL: String }
struct ChatContext { let tenantID: String; let session: UUID }
@MainActor final class ChatRuntime {
    static let shared = ChatRuntime()
    var userUID: String? = "user"
    var session = UUID()
    var cleanup: (() -> Void)?
    func context(for route: ChatRoute) -> ChatContext? { .init(tenantID: "tenant", session: session) }
    func isCurrent(_ context: ChatContext) -> Bool { context.session == session && userUID != nil }
    func registerCleanup(owner: AnyObject, action: @escaping @MainActor () -> Void) { cleanup = action }
}
@MainActor enum DNS1NodeRaceCoordinator {
    static var waiting: CheckedContinuation<DNS1Payload, Error>?
    static var suspend = true
    static var probes = 0
    static func load(_ source: DNS1Source, license: String) async throws -> DNS1Payload {
        if suspend { return try await withCheckedThrowingContinuation { waiting = $0 } }
        return payload
    }
    static var payload: DNS1Payload { .init(tcp: [DNS1TCPNode("127.0.0.1:1")!], http: []) }
    static func probe(_ node: DNS1TCPNode) async throws -> Bool { probes += 1; return true }
}
@main struct Checks {
    @MainActor static func spin(_ until: () -> Bool) async {
        for _ in 0..<1000 { if until() { return }; await Task.yield() }
        precondition(until(), "timed out waiting")
    }
    @MainActor static func main() async {
        let store = NetworkDiagnosticStore(checkDevice: { true }, checkInternet: { observe in
            observe(.started("https://test.invalid"))
            observe(.finished(.init(address: "https://test.invalid", passed: true, milliseconds: 1)))
            return true
        })
        store.start()
        await spin { DNS1NodeRaceCoordinator.waiting != nil }
        let old = DNS1NodeRaceCoordinator.waiting!
        DNS1NodeRaceCoordinator.waiting = nil
        store.cancel()
        DNS1NodeRaceCoordinator.suspend = false
        store.start()
        await spin { !store.running }
        precondition(store.completed && store.progress == 100 && store.activeSection == nil)
        let count = store.results.count
        old.resume(returning: DNS1NodeRaceCoordinator.payload)
        for _ in 0..<20 { await Task.yield() }
        precondition(store.results.count == count && DNS1NodeRaceCoordinator.probes == 1)
        print("PASS retry rejects previous run late completion")
        DNS1NodeRaceCoordinator.suspend = true
        store.start()
        await spin { DNS1NodeRaceCoordinator.waiting != nil }
        ChatRuntime.shared.session = UUID() // Same UID, new authentication.
        ChatRuntime.shared.cleanup?()
        DNS1NodeRaceCoordinator.waiting?.resume(returning: DNS1NodeRaceCoordinator.payload)
        DNS1NodeRaceCoordinator.waiting = nil
        for _ in 0..<20 { await Task.yield() }
        precondition(!store.running && store.results.count == 2 && DNS1NodeRaceCoordinator.probes == 1)
        print("PASS same UID new session cancels and rejects late callbacks")
        ChatRuntime.shared.userUID = nil
        store.start()
        precondition(!store.running && store.results.isEmpty)
        print("PASS signed out cannot start probes")
        store.reset()
        precondition(!store.completed && !store.running && store.progress == 0 && store.activeSection == nil && store.results.isEmpty && store.status == "准备检测")
        print("PASS reset restores ready presentation and clears previous results")
        ChatRuntime.shared.userUID = "user"
        store.start()
        store.reset()
        for _ in 0..<30 { await Task.yield() }
        precondition(store.sources.isEmpty && store.activeTargets.isEmpty && store.results.isEmpty && !store.running)
        print("PASS reset before task starts cannot restore stale targets")
        DNS1NodeRaceCoordinator.suspend = false
        var observer: (@MainActor (InternetConnectivityEvent) -> Void)?
        let eventStore = NetworkDiagnosticStore(checkDevice: { true }, checkInternet: { observe in
            observer = observe
            observe(.started("https://test.invalid"))
            observe(.finished(.init(address: "https://test.invalid", passed: true, milliseconds: 1)))
            return true
        })
        eventStore.start()
        await spin { !eventStore.running }
        let oldObserver = observer!
        eventStore.reset()
        eventStore.start()
        await spin { !eventStore.running }
        let newResults = eventStore.results.count
        oldObserver(.started("https://stale.invalid"))
        oldObserver(.finished(.init(address: "https://stale.invalid", passed: false, milliseconds: 99)))
        precondition(eventStore.activeTargets.isEmpty && eventStore.results.count == newResults)
        print("PASS late internet target and result callbacks cannot contaminate new round")
    }
}
