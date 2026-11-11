import Foundation

/// 最近使用是账号级偏好，与聊天会话、登录轮次及面板生命周期无关。
@MainActor struct ChatRecentEmojiHistory {
    private let defaults: UserDefaults
    private let key: String
    private let items: [ChatEmojiItem]
    private let capacity = 7

    init?(tenantID: String, userUID: String, defaults: UserDefaults = .standard,
          items: [ChatEmojiItem] = ChatEmojiCatalog.items) {
        guard !tenantID.isEmpty, !userUID.isEmpty else { return nil }
        self.defaults = defaults
        self.items = items
        let scope = [tenantID, userUID].map { Data($0.utf8).base64EncodedString() }.joined(separator: ".")
        key = "chat.recentEmoji.v1." + scope
    }

    func load() -> [ChatEmojiItem] {
        let catalog = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        return Array((defaults.stringArray(forKey: key) ?? []).compactMap { id in
            guard let item = catalog[id], seen.insert(id).inserted else { return nil }
            return item
        }.prefix(capacity))
    }

    func record(_ item: ChatEmojiItem) -> [ChatEmojiItem] {
        var recent = load()
        guard let canonical = items.first(where: { $0.id == item.id }) else { return recent }
        recent.removeAll { $0.id == canonical.id }
        recent.insert(canonical, at: 0)
        recent = Array(recent.prefix(capacity))
        defaults.set(recent.map(\.id), forKey: key)
        return recent
    }
}
