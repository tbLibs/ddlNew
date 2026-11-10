import Foundation

@main struct GroupActivityChecks {
    @MainActor static func main() async {
        func check(_ value: Bool, _ name: String) { precondition(value, name) }
        check(!GroupActivitySyncPolicy.isDue(lastSyncMilliseconds: 1000, nowMilliseconds: 3_601_000, interval: 3600), "boundary is strictly greater")
        check(GroupActivitySyncPolicy.isDue(lastSyncMilliseconds: 1000, nowMilliseconds: 3_601_001, interval: 3600), "milliseconds convert to seconds")
        check(GroupActivitySyncPolicy.isDue(lastSyncMilliseconds: 0, nowMilliseconds: 1000, interval: 3600), "initial sync")
        check(!GroupActivitySyncPolicy.isDue(lastSyncMilliseconds: 3000, nowMilliseconds: 1000, interval: 0), "future cursor does not overflow")
        let validPage = try! GroupActivityScorePage(data: ["records": [["memberUid": "member", "activityScore": "12"]], "pages": "1", "current": 1], expectedPage: 1)
        check(validPage.scores["member"] == 12 && !validPage.hasNext, "mixed scalar score payload")
        check((try? GroupActivityScorePage(data: ["records": [["memberUid": true, "activityScore": 2]], "pages": 1, "current": 1], expectedPage: 1)) == nil, "boolean member UID must reject whole page")
        check((try? GroupActivityScorePage(data: ["records": [], "pages": 2, "current": 1], expectedPage: 1)) == nil, "empty intermediate page cannot advance cursor")
        check((try? GroupActivityScorePage(data: ["records": [["memberUid": "member", "activityScore": 2.5]], "pages": 1, "current": 1], expectedPage: 1)) == nil, "fractional score rejected")
        let engine = GroupActivitySyncEngine()
        let auth = AuthState()
        var calls = 0; var writes = 0
        var pending: CheckedContinuation<Void, Never>?
        let work: @MainActor (@escaping @MainActor () -> Bool) async throws -> Void = { current in
            calls += 1
            await withCheckedContinuation { pending = $0 }
            if current() { writes += 1 }
        }
        engine.refresh(key: "a", lastSyncMilliseconds: 0, nowMilliseconds: 1000, interval: 1, valid: { auth.active }, operation: work)
        for _ in 0..<20 { await Task.yield() }
        engine.refresh(key: "a", lastSyncMilliseconds: 0, nowMilliseconds: 8000, interval: 1, valid: { auth.active }, operation: work)
        check(calls == 1, "only one request for same group")
        engine.reset(); auth.active = false
        pending?.resume(); pending = nil
        for _ in 0..<20 { await Task.yield() }
        check(writes == 0, "logout rejects delayed writes")
        auth.active = true
        engine.refresh(key: "a", lastSyncMilliseconds: 0, nowMilliseconds: 9000, interval: 3600, valid: { auth.active }) { current in if current() { calls += 1; writes += 1 } }
        for _ in 0..<20 { await Task.yield() }
        engine.refresh(key: "a", lastSyncMilliseconds: 0, nowMilliseconds: 15000, interval: 3600, valid: { auth.active }) { _ in calls += 1 }
        for _ in 0..<20 { await Task.yield() }
        check(calls == 2 && writes == 1, "empty successful result also honors interval")
        engine.reset()
        var attempts = 0
        enum ExpectedFailure: Error { case offline }
        engine.refresh(key: "retry", lastSyncMilliseconds: 0, nowMilliseconds: 1000, interval: 3600, valid: { true }) { _ in
            attempts += 1; throw ExpectedFailure.offline
        }
        for _ in 0..<20 { await Task.yield() }
        engine.refresh(key: "retry", lastSyncMilliseconds: 0, nowMilliseconds: 4000, interval: 3600, valid: { true }) { _ in attempts += 1 }
        for _ in 0..<20 { await Task.yield() }
        check(attempts == 1, "failed sync avoids immediate retry storm")
        engine.refresh(key: "retry", lastSyncMilliseconds: 0, nowMilliseconds: 7000, interval: 3600, valid: { true }) { _ in attempts += 1 }
        for _ in 0..<20 { await Task.yield() }
        check(attempts == 2, "failed sync does not consume success interval")
        print("Group activity: 13 checks passed")
    }
}

@MainActor private final class AuthState { var active = true }
