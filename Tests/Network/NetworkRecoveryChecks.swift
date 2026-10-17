import Foundation

@main
struct NetworkRecoveryChecks {
    @MainActor
    static func main() async throws {
        let fixture = Data(#"{"version":"v2","endpoints":{"http":{"ipList":[{"ip":"https://api.example.com:8443","sort":1}],"dnsList":[{"ip":"backup.example.com"}]},"tcp":{"ipList":[{"ip":"[2001:db8::1]:9000","sort":7}],"dnsList":[{"ip":"tcp.example.com","sort":"9001"}]}}}"#.utf8)
        let fallback = DNSHostSource.fallbackCandidates(
            cached: (0..<24).map { "cache\($0).example.com:8087" },
            builtIn: ["builtin.example.com:18087"])
        precondition(fallback.count == 9 && fallback.last?.source == .builtInFallback)
        precondition(fallback.last?.address == "builtin.example.com:18087")
        let config = try OSSLegacyConfigurationParser.parse(fixture)
        precondition(config.http.count == 2 && config.http[0].port == 8443)
        precondition(config.http[1].port == 443)
        precondition(config.tcp[0].host == "2001:db8::1" && config.tcp[0].port == 9000)
        precondition(config.tcp[1].port == 9001)
        for malformed in [#"{}"#, #"{"endpoints":{"http":[],"tcp":{}}}"#, #"{"endpoints":{"http":{"ipList":[{"ip":"api.example.com"}]},"tcp":{"ipList":[{"ip":"host:0","sort":9000},{"ip":"https://evil/path","sort":9000}]}}}"#] {
            do { _ = try OSSLegacyConfigurationParser.parse(Data(malformed.utf8)); preconditionFailure("Malformed navigation won") }
            catch { }
        }
        precondition(OSSLegacyConfigurationParser.endpoint("host:65536", defaultPort: 9000) == nil)
        precondition(OSSLegacyConfigurationParser.endpoint("host:2/path", defaultPort: 9000) == nil)
        precondition(OSSLegacyConfigurationParser.endpoint("https://u:p@host", defaultPort: 443, http: true) == nil)
        // 使用独立 OpenSSL 生成的 AES-128-ECB 测试密文，密钥为小写 MD5(邀请码)。
        let encrypted = "90i8osyVB5GCOGpXNyCwK7ylek28Ee64GxLYdYV0HXLPlRLr5Aqb7grREtofQdse0t44UYP6iN98CuEh5x4Szc2IkgWjrYM0T+Lyw6i5F5Lrk49YxWSgytqtEVTVJGC5GiGvPake2kR+vsP7lgdnnihk/p8+CAfnmK30hD/9r3I="
        let decrypted = try OSSLegacyConfigurationParser.decodeEncrypted(Data(("\n" + encrypted + "\n").utf8), lastLiceseId: "fixture-license")
        precondition(decrypted.http[0].port == 8443 && decrypted.tcp[0].port == 9000)
        do { _ = try OSSLegacyConfigurationParser.decodeEncrypted(Data(encrypted.utf8), lastLiceseId: "another-license"); preconditionFailure("Wrong license decrypted") } catch { }
        do { _ = try OSSLegacyConfigurationParser.decodeEncrypted(Data("invalid".utf8), lastLiceseId: "fixture-license"); preconditionFailure("Malformed Base64 won") } catch { }
        await reconnectChecks()
        print("Network configuration and reconnect checks passed")
    }
    @MainActor
    static func reconnectChecks() async {
        let session = IMReconnectSession(userUID: "fixture-user", lastLiceseId: "fixture-license")
        let cached = OSSLegacyEndpoint(host: "cached.example.com", port: 9000)
        let fresh = OSSLegacyEndpoint(host: "fresh.example.com", port: 9001)
        var refreshes = 0
        var now: TimeInterval = 100
        var valid = true
        let engine = IMLoggedInReconnectEngine(session: session, clock: { now },
            isCurrentSession: { $0 == session && valid }, cachedNodes: { [cached] },
            refreshNodes: { refreshes += 1; return [fresh] }, probe: { $0 == fresh })
        let winner = await result(engine)
        precondition(winner.0 == fresh && refreshes == 1)
        let cooled = await result(engine)
        precondition(cooled.0 == nil && cooled.1 == "navigation_refresh_cooldown" && refreshes == 1)
        now += 61
        _ = await result(engine)
        precondition(refreshes == 2)

        let direct = IMLoggedInReconnectEngine(session: session, isCurrentSession: { _ in true },
            cachedNodes: { [cached, cached] }, refreshNodes: { preconditionFailure("Cached winner refreshed") },
            probe: { _ in true })
        let directResult = await result(direct)
        precondition(directResult.0 == cached)

        // DNS1 刷新返回的首项已经完成 ECDH；缓存仍须探测，刷新首胜直接交 SDK 正式连接。
        var nativeProbes = 0
        let native = IMLoggedInReconnectEngine(session: session, refreshedNodesAreProbed: true,
            isCurrentSession: { _ in true }, cachedNodes: { [cached] }, refreshNodes: { [fresh, cached] },
            probe: { _ in nativeProbes += 1; return false })
        let nativeResult = await result(native)
        precondition(nativeResult.0 == fresh && nativeProbes == 1)

        enum ProbeFailure: Error { case rejected }
        var throwRefreshes = 0
        let partialFailure = IMLoggedInReconnectEngine(session: session,
            isCurrentSession: { _ in true }, cachedNodes: { [cached, fresh] },
            refreshNodes: { throwRefreshes += 1; return [] },
            probe: { node in
                if node == cached { throw ProbeFailure.rejected }
                try await Task<Never, Never>.sleep(nanoseconds: 5_000_000)
                return true
            })
        let survivingResult = await result(partialFailure)
        precondition(survivingResult.0 == fresh && throwRefreshes == 0)
        let allThrow = IMLoggedInReconnectEngine(session: session,
            isCurrentSession: { _ in true }, cachedNodes: { [cached] },
            refreshNodes: { throwRefreshes += 1; return [fresh] },
            probe: { node in if node == cached { throw ProbeFailure.rejected }; return true })
        let afterThrow = await result(allThrow)
        precondition(afterThrow.0 == fresh && throwRefreshes == 1)

        var timeoutCallbacks = 0
        let deadline = IMLoggedInReconnectEngine(session: session, timeout: 0.01,
            isCurrentSession: { _ in true }, cachedNodes: { [] },
            refreshNodes: { try await Task<Never, Never>.sleep(nanoseconds: 80_000_000); return [fresh] },
            probe: { _ in true })
        let timeoutResult: (OSSLegacyEndpoint?, String?) = await withCheckedContinuation { continuation in
            deadline.begin { node, reason in timeoutCallbacks += 1; continuation.resume(returning: (node, reason)) }
        }
        precondition(timeoutResult.0 == nil && timeoutResult.1 == "tcp_probe_timeout")
        try? await Task<Never, Never>.sleep(nanoseconds: 100_000_000)
        precondition(timeoutCallbacks == 1)

        var staleCallbacks = 0
        let stale = IMLoggedInReconnectEngine(session: session, timeout: 0.04,
            isCurrentSession: { _ in valid }, cachedNodes: { [cached] }, refreshNodes: { [fresh] },
            probe: { _ in try? await Task<Never, Never>.sleep(nanoseconds: 30_000_000); return true })
        stale.begin { _, _ in staleCallbacks += 1 }
        try? await Task<Never, Never>.sleep(nanoseconds: 2_000_000)
        valid = false
        stale.cancel()
        try? await Task<Never, Never>.sleep(nanoseconds: 60_000_000)
        precondition(staleCallbacks == 0)

        valid = true
        var secondCallbacks = 0
        stale.begin { _, _ in staleCallbacks += 1 }
        stale.begin { _, _ in secondCallbacks += 1 }
        try? await Task<Never, Never>.sleep(nanoseconds: 60_000_000)
        precondition(staleCallbacks == 0 && secondCallbacks == 1)
    }

    @MainActor
    static func result(_ engine: IMLoggedInReconnectEngine) async -> (OSSLegacyEndpoint?, String?) {
        await withCheckedContinuation { continuation in
            engine.begin { continuation.resume(returning: ($0, $1)) }
        }
    }
}
