import Foundation

@main struct RecoveryChecks {
    @MainActor static func main() async throws {
        func expect(_ value: Bool, _ name: String) { precondition(value, name); print("PASS: \(name)") }
        func settle(_ condition: @MainActor () -> Bool) async throws {
            for _ in 0..<500 { if condition() { return }; try await Task.sleep(nanoseconds: 1_000_000) }
            fatalError("timeout")
        }
        var cacheReads = 0
        var calls = 0
        var held: CheckedContinuation<Void, Error>?
        let recovery = MessageSessionRecovery(retryDelay: 0.005, loadLocalSnapshot: { _ in cacheReads += 1 }, attempt: { _ in
            calls += 1
            try await withCheckedThrowingContinuation { held = $0 }
        }, invalidate: { _ in })
        recovery.prepare(userUID: "a", license: "club")
        expect(calls == 0 && recovery.hasPendingIdentity, "prepare is local only")
        recovery.setAvailable(false); recovery.ensureRecovery()
        try await Task.sleep(nanoseconds: 10_000_000)
        expect(calls == 0 && cacheReads == 1, "offline loads cached list before network attempts")
        recovery.retryLocalSnapshot()
        try await settle { cacheReads == 2 }
        expect(calls == 0, "manual local cache retry works while offline without connecting")
        recovery.setAvailable(true); recovery.ensureRecovery(); recovery.ensureRecovery()
        try await settle { calls == 1 }
        expect(calls == 1, "repeated page appearance shares task")
        held?.resume(throwing: MessageRecoveryFailure.retryable); held = nil
        try await settle { calls == 2 }
        expect(recovery.hasPendingIdentity && cacheReads == 2, "transient failure retains identity without reloading initial cache")
        recovery.cancel(); recovery.prepare(userUID: "a", license: "club")
        held?.resume(); held = nil
        try await Task.sleep(nanoseconds: 10_000_000)
        expect(recovery.hasPendingIdentity && calls == 2, "old same-UID completion cannot consume new identity")
        recovery.ensureRecovery(); try await settle { calls == 3 }
        held?.resume(throwing: MessageRecoveryFailure.local("storage")); held = nil
        try await settle { recovery.failureMessage != nil }
        recovery.ensureRecovery()
        try await Task.sleep(nanoseconds: 10_000_000)
        expect(calls == 3 && recovery.hasPendingIdentity, "local failure stops automatic retry")
        recovery.retry(); try await settle { calls == 4 }
        held?.resume(); held = nil
        try await settle { !recovery.hasPendingIdentity }
        expect(recovery.failureMessage == nil, "successful retry completes recovery")
        var invalidated = 0
        let rejected = MessageSessionRecovery(attempt: { _ in throw MessageRecoveryFailure.invalidIdentity }, invalidate: { _ in invalidated += 1 })
        rejected.prepare(userUID: "a", license: "club"); rejected.ensureRecovery()
        try await settle { invalidated == 1 }
        expect(!rejected.hasPendingIdentity, "explicit rejection revokes pending identity")
        print("Recovery checks passed")
    }
}
