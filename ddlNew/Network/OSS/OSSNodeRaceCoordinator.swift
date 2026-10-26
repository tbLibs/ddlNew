import Foundation

struct OSSRaceWinner: Sendable {
    let source: DNSHostSource
    let node: DNSResolvedHost
    let navigation: OSSNavigationResult
}

/// 所有首次连接和重连统一使用 DNS1；来源耗尽后返回失败。
@MainActor enum OSSNodeRaceCoordinator {
    static func race(lastLiceseId: String, useDNS1Cache: Bool = false) async throws -> OSSRaceWinner {
        try await DNS1NodeRaceCoordinator.race(license: lastLiceseId, useCache: useDNS1Cache)
    }
}
