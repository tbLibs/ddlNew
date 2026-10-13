// Created by taobo on 2026/10/13.
import Foundation

/// 本地搜索结果只持有稳定标识和展示快照，打开时重新检查当前资料。
struct GlobalSearchResult: Identifiable, Sendable {
    let id: String
    let kind: GlobalSearchKind
    let peerID: String
    let title: String
    let detail: String
    let avatar: String
    let messageID: String?
    let date: Date?
}
