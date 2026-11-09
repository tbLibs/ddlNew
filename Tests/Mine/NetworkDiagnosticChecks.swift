import Foundation

@main struct Checks {
    @MainActor static func main() async throws {
        let sources = [DNS1Source(kind: .main, address: "main"), DNS1Source(kind: .backup, address: "backup"), DNS1Source(kind: .bin, address: "bin")]
        let payload = DNS1Payload(tcp: [DNS1TCPNode("127.0.0.1:1")!], http: [])
        var loads: [String] = []
        var results: [NetworkDiagnosticResult] = []
        try await NetworkDiagnosticRunner.run(sources: sources, load: { source in
            loads.append(source.address)
            if source.kind == .main { throw DNS1Error.unavailable }
            return payload
        }, probe: { _ in true }, emit: { results.append($0) })
        precondition(loads == ["main", "backup"])
        precondition(results.count == 3 && results.last?.passed == true)
        precondition(results[0].targets == ["main"])
        precondition(results[1].targets == ["backup", "127.0.0.1:1"])
        precondition(results[2].targets == ["127.0.0.1:1"])
        print("PASS load failure falls back; success stops before BIN; exact targets retained")
        loads = []; results = []
        try await NetworkDiagnosticRunner.run(sources: sources, load: { source in loads.append(source.address); return payload }, probe: { _ in false }, emit: { results.append($0) })
        precondition(loads == ["main", "backup", "bin"] && results.filter { !$0.passed }.count == 3)
        print("PASS all probe failures advance through BIN")
        results = []
        let task = Task { @MainActor in
            try await NetworkDiagnosticRunner.run(sources: sources, load: { _ in
                // Simulates a transport that ignores cancellation and delivers late.
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                return payload
            }, probe: { _ in true }, emit: { results.append($0) })
        }
        await Task.yield(); task.cancel()
        do { try await task.value; fatalError("cancel should throw") } catch is CancellationError { }
        precondition(results.isEmpty)
        print("PASS cancellation rejects late source result")
        loads = []
        try await NetworkDiagnosticRunner.run(sources: [.init(kind: .cache, address: "cache")], load: { source in loads.append(source.address); return payload }, probe: { _ in true }, emit: { _ in fatalError("cache result") })
        precondition(loads.isEmpty)
        print("PASS cached candidates never mask diagnostic failures")
        results = []
        do {
            try await NetworkDiagnosticRunner.run(sources: sources, load: { _ in payload }, probe: { _ in throw CancellationError() }, emit: { results.append($0) })
            fatalError("probe cancel should throw")
        } catch is CancellationError { }
        precondition(results.count == 1)
        print("PASS probe cancellation stops later sources")
        let ipv6 = DNS1TCPNode("[2001:db8::1]:10443")!
        results = []
        try await NetworkDiagnosticRunner.run(sources: [sources[0]], load: { _ in .init(tcp: [ipv6], http: []) }, probe: { _ in true }, emit: { results.append($0) })
        precondition(results[0].targets == ["main", "[2001:db8::1]:10443"] && results[1].targets == ["[2001:db8::1]:10443"])
        print("PASS IPv6 endpoints preserve brackets and explicit port in both sections")
    }
}
