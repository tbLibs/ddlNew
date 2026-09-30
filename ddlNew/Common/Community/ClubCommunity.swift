//
//  ClubCommunity.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation
import Combine

/// 消息和通讯录共享的本地演示状态，尚未替换为 SDK 业务数据。
@MainActor final class ClubCommunity: ObservableObject {
    @Published private(set) var messages = ClubMessage.samples
    @Published private(set) var favorites: Set<String> = ["azhe", "xiaoyu"]
    @Published private(set) var conversations: [String: [ChatEntry]] = Dictionary(uniqueKeysWithValues:
        ClubMessage.samples.map { ($0.id, [ChatEntry(text: $0.body, isOutgoing: false, time: $0.time)]) }
    )
    @Published var drafts: [String: String] = [:]
    let contacts = ClubContact.samples
    var unreadCount: Int { messages.filter(\.unread).count }

    func openConversation(with contact: ClubContact) -> ClubMessage {
        let id = "contact-\(contact.id)"
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].unread = false
            return messages[index]
        }
        let conversation = ClubMessage(id: id, title: contact.name, preview: "点击开始聊天", body: "", time: "", icon: "person", isNotice: false, unread: false, contactID: contact.id)
        conversations[id] = []
        messages.insert(conversation, at: 0)
        return conversation
    }

    func markRead(_ id: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].unread = false
    }
    func markAllRead() {
        for index in messages.indices { messages[index].unread = false }
    }
    func sendMessage(in conversationID: String) {
        let text = (drafts[conversationID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let index = messages.firstIndex(where: { $0.id == conversationID }) else { return }
        let time = Date().formatted(date: .omitted, time: .shortened)
        conversations[conversationID, default: []].append(ChatEntry(text: text, isOutgoing: true, time: time))
        drafts[conversationID] = ""
        var conversation = messages.remove(at: index)
        conversation.preview = "我：\(text)"
        conversation.time = "刚刚"
        conversation.unread = false
        messages.insert(conversation, at: 0)
    }

    func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
    }
    func eraseSession() {
        messages = []
        conversations = [:]
        drafts = [:]
        favorites = []
    }
}
