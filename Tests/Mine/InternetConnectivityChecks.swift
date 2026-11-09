import Foundation

@main struct InternetChecks {
    @MainActor static func main() async {
        for winner in 0..<4 {
            var visited: [String] = []
            var attempts: [InternetConnectivityAttempt] = []
            var starts: [String] = []
            let passed = await InternetConnectivityCheck.run(observe: { event in
                switch event {
                case .started(let address): starts.append(address)
                case .finished(let attempt): attempts.append(attempt)
                }
            }) { url in
                let index = visited.count
                visited.append(url.absoluteString)
                if index != winner { throw URLError(.timedOut) }
                let json = index == 0 ? "{\"country\":\"CN\"}" : "{\"country_code\":\"CN\"}"
                return (Data(json.utf8), index == 3 ? 204 : 200)
            }
            precondition(passed && visited == Array(InternetConnectivityCheck.addresses.prefix(winner + 1)))
            precondition(starts == visited && attempts.map(\.address) == visited)
            precondition(attempts.last?.passed == true && attempts.dropLast().allSatisfy { !$0.passed })
            precondition(attempts.allSatisfy { $0.milliseconds >= 0 })
        }
        print("PASS all four fallback positions and stop on first success")
        var count = 0
        let rejected = await InternetConnectivityCheck.run { _ in
            count += 1
            return (Data("{\"country\":false,\"country_code\":\"\"}".utf8), 200 + (count == 4 ? 1 : 0))
        }
        precondition(!rejected && count == 4)
        print("PASS invalid country fields and non-200/204 final response rejected")
        count = 0
        let final200 = await InternetConnectivityCheck.run { _ in
            count += 1
            return (Data("<html>portal</html>".utf8), 200)
        }
        precondition(final200 && count == 4)
        print("PASS JSON endpoints reject HTML; final endpoint accepts 200 like xgd")
        count = 0
        let failures = await InternetConnectivityCheck.run { _ in count += 1; return (Data("{\"country\":\"CN\"}".utf8), 500) }
        precondition(!failures && count == 4)
        print("PASS all four HTTP failures return unreachable")
        count = 0
        var lateResults = 0
        let task = Task { @MainActor in
            await InternetConnectivityCheck.run(observe: { if case .finished = $0 { lateResults += 1 } }) { _ in
                count += 1
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                return (Data("{\"country\":\"CN\"}".utf8), 200)
            }
        }
        while count == 0 { await Task.yield() }
        task.cancel()
        let cancelledResult = await task.value
        precondition(!cancelledResult && count == 1 && lateResults == 0)
        print("PASS cancellation ignores late success and prevents fallback")
    }
}
