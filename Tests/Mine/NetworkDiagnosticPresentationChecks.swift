@main struct PresentationChecks {
    static func main() {
        precondition(NetworkDiagnosticStepState.resolve(passes: [false], active: false, running: true, completed: false, interrupted: false) == .recorded)
        precondition(NetworkDiagnosticStepState.resolve(passes: [false], active: true, running: true, completed: false, interrupted: false) == .active)
        precondition(NetworkDiagnosticStepState.resolve(passes: [false, true], active: false, running: false, completed: true, interrupted: false) == .partial)
        precondition(NetworkDiagnosticStepState.resolve(passes: [false], active: false, running: false, completed: true, interrupted: false) == .failed)
        precondition(NetworkDiagnosticStepState.resolve(passes: [], active: false, running: false, completed: true, interrupted: false) == .skipped)
        precondition(NetworkDiagnosticStepState.resolve(passes: [], active: false, running: false, completed: false, interrupted: true) == .interrupted)
        precondition(NetworkDiagnosticStepState.pendingInternetTitle(hasReachableAddress: true, completed: false, interrupted: false) == "未请求 · 已有可达地址")
        precondition(NetworkDiagnosticStepState.pendingInternetTitle(hasReachableAddress: false, completed: false, interrupted: false) == "待检测")
        print("PASS in-flight fallback is not final failure; mixed outcomes, skipped and interrupted are distinct")
    }
}
