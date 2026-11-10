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
        if hasReachableAddress { return L10n.tr("未请求 · 已有可达地址") }
        if completed { return L10n.tr("未请求") }
        return interrupted ? L10n.tr("未完成") : L10n.tr("待检测")
    }

    var title: String {
        switch self {
        case .waiting: return L10n.tr("待检测")
        case .active: return L10n.tr("检测中")
        case .recorded: return L10n.tr("已有结果")
        case .passed: return L10n.tr("全部通过")
        case .partial: return L10n.tr("部分通过")
        case .failed: return L10n.tr("未通过")
        case .skipped: return L10n.tr("未执行")
        case .interrupted: return L10n.tr("未完成")
        }
    }
    var needsAttention: Bool { self == .partial || self == .failed || self == .interrupted }
}
