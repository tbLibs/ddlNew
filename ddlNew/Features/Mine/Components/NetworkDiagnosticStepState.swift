/// 展示状态与检测策略分离：回退未结束时，不提前给整步下最终结论。
nonisolated enum NetworkDiagnosticStepState: Equatable {
    case waiting, active, recorded, passed, partial, failed, skipped, interrupted

    static func resolve(passes: [Bool], active: Bool, running: Bool, completed: Bool,
                        interrupted: Bool) -> Self {
        if active { return .active }
        if !completed {
            if !passes.isEmpty { return .recorded }
            return interrupted && !running ? .interrupted : .waiting
        }
        if passes.isEmpty { return .skipped }
        if passes.allSatisfy({ $0 }) { return .passed }
        return passes.contains(true) ? .partial : .failed
    }

    static func pendingInternetTitle(hasReachableAddress: Bool, completed: Bool, interrupted: Bool) -> String {
        if hasReachableAddress { return "未请求 · 已有可达地址" }
        if completed { return "未请求" }
        return interrupted ? "未完成" : "待检测"
    }

    var title: String {
        switch self {
        case .waiting: return "待检测"
        case .active: return "检测中"
        case .recorded: return "已有结果"
        case .passed: return "全部通过"
        case .partial: return "部分通过"
        case .failed: return "未通过"
        case .skipped: return "未执行"
        case .interrupted: return "未完成"
        }
    }
    var needsAttention: Bool { self == .partial || self == .failed || self == .interrupted }
}
