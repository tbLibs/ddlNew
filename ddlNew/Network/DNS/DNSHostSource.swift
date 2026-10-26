import Foundation

/// 唯一导航来源；旧五源缓存只迁移邀请码，不复用节点。
nonisolated enum DNSHostSource: String, Codable, CaseIterable, Sendable {
    case dns1 = "DNS1"
}

nonisolated struct DNSResolvedHost: Equatable, Sendable {
    let urlString: String
    let type: String
}
