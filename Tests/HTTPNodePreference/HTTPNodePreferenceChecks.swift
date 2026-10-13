import Foundation

@main
struct HTTPNodePreferenceChecks {
    static let slow = URL(string: "https://slow.example.com")!
    static let fast = URL(string: "https://fast.example.com")!

    @MainActor
    static func main() async throws {
        try parsingAndResponseChecks()
        foregroundChecks()
        await sortingAndFailureChecks()
        await isolationAndReentryChecks()
        await externalHostUpdateInvalidatesRound()
        await hostChangedAwayAndBackInvalidatesRound()
        print("HTTP node preference checks passed: legacy flags, real HTTP success, RTT ranking, deduplication, cooldown, lifecycle and session isolation")
    }

    static func context(uid: String = "A", license: String = "club", nav: String = "1", enabled: Bool = true,
                        interval: TimeInterval = 0) -> IMHTTPNodePreferenceContext {
        IMHTTPNodePreferenceContext(userUID: uid, lastLiceseId: license, navigationGeneration: nav,
                                    enabled: enabled, interval: interval, nodes: [slow, fast, fast])
    }

    static func parsingAndResponseChecks() throws {
        precondition(context().pollingInterval == 300)
        precondition(context(interval: 10).pollingInterval == 10)
        precondition(context(interval: -.infinity).pollingInterval == 300)
        let payload = Data("""
        {"is_merge_version":"1","ping_interval_second":"27", "endpoints":{
            "http":{"ipList":[{"ip":"one.example.com"}]},
            "tcp":{"ipList":[{"ip":"one.example.com:9000"}]}}}
        """.utf8)
        let legacy = try OSSLegacyConfigurationParser.parse(payload)
        precondition(legacy.httpNodePreference.enabled && legacy.httpNodePreference.intervalSeconds == 27)
        var json = try JSONSerialization.jsonObject(with: payload) as! [String: Any]
        json.removeValue(forKey: "is_merge_version")
        json.removeValue(forKey: "ping_interval_second")
        let absent = try OSSLegacyConfigurationParser.parse(JSONSerialization.data(withJSONObject: json))
        precondition(!absent.httpNodePreference.enabled && absent.httpNodePreference.intervalSeconds == 0)
        precondition(IMHTTPNodePreferenceURL.base("HTTP://FAST.EXAMPLE.COM:443/") == fast)
        precondition(IMHTTPNodePreferenceURL.base("https://user:pass@fast.example.com") == nil)
        precondition(IMHTTPNodePreferenceURL.base("https://fast.example.com/path") == nil)
        precondition(IMHTTPNodePreferenceURL.base("https://fast.example.com?query") == nil)
        precondition(IMHTTPNodePreferenceURL.base("https://fast.example.com:0") == nil)
        let url = fast.appending(path: "/zlcpig")
        precondition(url.path == "/zlcpig")
        func response(_ code: Int, _ target: URL) -> HTTPURLResponse {
            HTTPURLResponse(url: target, statusCode: code, httpVersion: nil, headerFields: nil)!
        }
        precondition(IMHTTPNodePreferenceURL.succeeded(response: response(200, url), requestedURL: url))
        for code in [301, 401, 404, 500, 503] {
            precondition(!IMHTTPNodePreferenceURL.succeeded(response: response(code, url), requestedURL: url))
        }
        precondition(!IMHTTPNodePreferenceURL.succeeded(response: response(200, slow.appending(path: "zlcpig")), requestedURL: url))
        precondition(!IMHTTPNodePreferenceURL.succeeded(response: response(200, fast.appending(path: "different")), requestedURL: url))
        precondition(!IMHTTPNodePreferenceURL.sameOrigin(fast, URL(string: "https://fast.example.com:8443")!))
    }

    static func foregroundChecks() {
        var gate = IMForegroundSessionGate(isInBackground: false)
        precondition(!gate.takeForegroundCheck())
        gate.enteredBackground()
        precondition(gate.takeForegroundCheck())
        precondition(!gate.takeForegroundCheck())
        gate.enteredBackground()
        precondition(gate.takeForegroundCheck())
        var installedInBackground = IMForegroundSessionGate(isInBackground: true)
        precondition(installedInBackground.takeForegroundCheck())
    }

    @MainActor
    static func sortingAndFailureChecks() async {
        var active: IMHTTPNodePreferenceContext? = context(enabled: false)
        var host = slow
        var hostRevision: UInt64 = 0
        var probes = 0
        var switches = 0
        var now: TimeInterval = 100
        var mode = 0
        let engine = IMHTTPNodePreferenceEngine(clock: { now }, context: { active }, current: { host },
            hostRevision: { hostRevision },
            probe: { node in
                probes += 1
                if mode == 1 { return nil }
                if mode == 2 { return node == slow ? 20 : 100 }
                return node == slow ? 300 : 100
            }, select: { node, snapshot in
                precondition(snapshot == active)
                switches += 1; host = node; hostRevision += 1; return true
            })
        await engine.runOnce()
        precondition(probes == 0)
        active = context()
        await engine.runOnce()
        precondition(probes == 2 && switches == 1 && host == fast)
        precondition(engine.rankedSamples.count == 2 && engine.rankedSamples.first?.averageMilliseconds == 100)
        mode = 1
        await engine.runOnce()
        precondition(host == fast && switches == 1 && engine.rankedSamples.allSatisfy { !$0.lastSucceeded })
        mode = 2
        // 同会话新导航必须清空历史成功次数，再用新版本的同轮 HTTP RTT 排序。
        active = context(nav: "2")
        await engine.runOnce()
        precondition(host == slow && switches == 2 && engine.rankedSamples.first?.successCount == 1)
        mode = 0
        await engine.runOnce()
        precondition(host == slow && switches == 2)
        precondition(engine.rankedSamples.allSatisfy { $0.successCount == 2 },
                     "择优自身切换 Host 后必须保留统计和切换冷却")
        now += 60
        await engine.runOnce()
        precondition(host == fast && switches == 3)
        active = nil
        let oldProbes = probes
        await engine.runOnce()
        precondition(probes == oldProbes)
    }

    @MainActor
    static func isolationAndReentryChecks() async {
        var active: IMHTTPNodePreferenceContext? = context()
        var pending: [CheckedContinuation<Double?, Error>] = []
        var switches = 0
        let engine = IMHTTPNodePreferenceEngine(context: { active }, current: { slow },
            probe: { _ in try await withCheckedThrowingContinuation { pending.append($0) } },
            select: { _, _ in switches += 1; return true })
        for next in [context(uid: "B"), context(license: "another"), context(nav: "2"), context(enabled: false)] {
            active = context()
            let task = Task { await engine.runOnce() }
            while pending.count < 2 { await Task.yield() }
            await engine.runOnce()
            precondition(pending.count == 2)
            active = next
            pending.forEach { $0.resume(returning: 10) }; pending.removeAll()
            await task.value
            precondition(switches == 0 && engine.rankedSamples.isEmpty && !engine.isProbing)
        }
        // 回前台即使恢复相同账号和导航，后台取消前的迟到响应也必须失效。
        active = context()
        let task = Task { await engine.runOnce() }
        while pending.count < 2 { await Task.yield() }
        engine.cancel()
        pending.forEach { $0.resume(returning: 10) }; pending.removeAll()
        await task.value
        precondition(switches == 0 && engine.rankedSamples.isEmpty && !engine.isProbing)
    }

    @MainActor
    static func externalHostUpdateInvalidatesRound() async {
        let external = URL(string: "https://external.example.com")!
        var host = slow
        var pending: [(URL, CheckedContinuation<Double?, Error>)] = []
        var switches = 0
        let engine = IMHTTPNodePreferenceEngine(context: { context() }, current: { host },
            probe: { node in try await withCheckedThrowingContinuation { pending.append((node, $0)) } },
            select: { node, _ in switches += 1; host = node; return true })
        let round = Task { await engine.runOnce() }
        while pending.count < 2 { await Task.yield() }
        // 模拟 SDK cimUserUpdateHttpNode：账号和导航未变，但正式使用的 Host 已被更新。
        host = external
        pending.forEach { $0.1.resume(returning: $0.0 == fast ? 10 : 300) }
        pending.removeAll()
        await round.value
        precondition(host == external && switches == 0, "外部 Host 更新后，旧轮测速不能覆盖新 Host")
        precondition(engine.rankedSamples.isEmpty && !engine.isProbing)
    }

    @MainActor
    static func hostChangedAwayAndBackInvalidatesRound() async {
        var host = slow
        var hostRevision: UInt64 = 0
        var pending: [(URL, CheckedContinuation<Double?, Error>)] = []
        var switches = 0
        let engine = IMHTTPNodePreferenceEngine(context: { context() }, current: { host },
            hostRevision: { hostRevision },
            probe: { node in try await withCheckedThrowingContinuation { pending.append((node, $0)) } },
            select: { node, _ in switches += 1; host = node; return true })
        let round = Task { await engine.runOnce() }
        while pending.count < 2 { await Task.yield() }
        // SDK 在旧轮等待期间切到 B 再切回 A，字符串相等仍然是另一次 Host 决策。
        host = fast
        hostRevision += 1
        host = slow
        hostRevision += 1
        pending.forEach { $0.1.resume(returning: $0.0 == fast ? 10 : 300) }
        pending.removeAll()
        await round.value
        precondition(host == slow && switches == 0, "Host A→B→A 后，旧轮测速也不能覆盖 SDK 的新决策")
        precondition(engine.rankedSamples.isEmpty && !engine.isProbing)
    }
}
