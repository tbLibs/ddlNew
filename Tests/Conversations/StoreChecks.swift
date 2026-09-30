//
//  StoreChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation

@MainActor
private final class FakeConversationsClient: ConversationsClient {
    var recordsByUser: [String: [ConversationRecord]] = [:]
    var callback: (@MainActor (ConversationsChange) -> Void)?

    func observe(for userUID: String, _ onChange: @escaping @MainActor (ConversationsChange) -> Void) {
        callback = onChange
    }

    func stopObserving() { callback = nil }

    func loadConversations(for userUID: String) async throws -> [ConversationRecord] {
        recordsByUser[userUID] ?? []
    }
}

@main
private struct StoreChecks {
    @MainActor
    static func main() async {
        let client = FakeConversationsClient()
        let first = ConversationRecord(id: "a", title: "A", avatarURL: "", kind: .single,
                                       preview: "hi", latestTime: .now, unreadCount: 2,
                                       isMarkedUnread: false, isPinned: false, isMuted: false, isDraft: false)
        let second = ConversationRecord(id: "b", title: "B", avatarURL: "", kind: .group,
                                        preview: "hi", latestTime: .now, unreadCount: 4,
                                        isMarkedUnread: true, isPinned: false, isMuted: true, isDraft: false)
        client.recordsByUser["A"] = [first, second]
        client.recordsByUser["B"] = []
        let store = ConversationsStore(client: client)
        store.prepare(for: "A")
        let oldCallback = client.callback
        await store.reload()
        precondition(store.conversations.map(\.id).sorted() == ["a", "b"])
        precondition(store.totalUnreadCount == 2)
        client.callback?(.syncFinished)
        precondition(!store.isSyncing)

        store.prepare(for: "B")
        oldCallback?(.syncFailed("旧账号错误"))
        await store.reload()
        precondition(store.conversations.isEmpty && store.totalUnreadCount == 0)
        precondition(store.errorMessage == nil)
        store.reset()
        precondition(store.conversations.isEmpty && !store.isSyncing)
        print("ConversationsStore checks passed")
    }
}
