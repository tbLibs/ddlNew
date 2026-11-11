import Foundation

@main struct HistoryChecks {
    @MainActor static func main() throws {
        let suite = "invalid.anonymous.recentemoji." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let items = try ChatEmojiCatalog.load(from: URL(fileURLWithPath: CommandLine.arguments[1]))
        func history(_ tenant: String = "tenant-a", _ user: String = "user-a") -> ChatRecentEmojiHistory {
            ChatRecentEmojiHistory(tenantID: tenant, userUID: user, defaults: defaults, items: items)!
        }
        precondition(history().load().isEmpty)
        for item in items.prefix(10) { _ = history().record(item) }
        precondition(history().load().map(\.id) == items.prefix(10).suffix(7).reversed().map(\.id))
        _ = history().record(items[5])
        precondition(history().load().map(\.id) == [items[5].id] + [9,8,7,6,4,3].map { items[$0].id })
        precondition(history("tenant-b").load().isEmpty)
        precondition(history("tenant-a", "user-b").load().isEmpty)
        _ = history("tenant-b").record(items[1])
        precondition(history().load().first?.id == items[5].id)
        precondition(ChatRecentEmojiHistory(tenantID: "", userUID: "user", defaults: defaults) == nil)
        precondition(ChatRecentEmojiHistory(tenantID: "tenant", userUID: "", defaults: defaults) == nil)
        // Persist only catalog IDs; unknown IDs and duplicate/corrupt history are safely ignored.
        let baseline = history().load().map(\.id)
        _ = history().record(ChatEmojiItem(token: "[unknown]", image: "unknown"))
        precondition(history().load().map(\.id) == baseline)
        let key = defaults.dictionaryRepresentation().keys.first { defaults.stringArray(forKey: $0) == baseline }!
        defaults.set(["[unknown]", items[1].id, items[1].id, items[2].id], forKey: key)
        precondition(history().load().map(\.id) == [items[1].id, items[2].id])
        defaults.set("corrupt", forKey: key)
        precondition(history().load().isEmpty)
        _ = history().record(items[3])
        precondition(history().load().map(\.id) == [items[3].id])
        print("Recent emoji persistence, ordering, deduplication, capacity, account isolation and invalid-data checks passed")
    }
}
