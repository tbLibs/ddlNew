//
//  ChatForwardRecipientView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

struct ChatForwardRecipientView: View {
    let messages: [ChatMessageRecord]
    let context: ChatContext
    @ObservedObject var chat: ChatStore
    @ObservedObject private var conversations = LoginSessionService.shared.conversations
    @ObservedObject private var groups = LoginSessionService.shared.groups
    @ObservedObject private var contacts = LoginSessionService.shared.contacts
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<String> = []
    @State private var merged = false
    @State private var busy = false
    @State private var results: [String] = []
    @State private var query = ""

    private var recipients: [ChatRoute] {
        var map: [String: ChatRoute] = [:]
        for contact in contacts.contacts where !contact.isDeleted { let route = ChatRoute(id: contact.id, kind: .single, title: contact.displayName, avatarURL: contact.avatar); map[key(route)] = route }
        for group in groups.groups { let route = ChatRoute(id: group.id, kind: .group, title: group.name, avatarURL: group.avatar); map[key(route)] = route }
        for conversation in conversations.conversations where [.single, .group].contains(conversation.kind) { let route = ChatRoute(id: conversation.id, kind: conversation.kind, title: conversation.title, avatarURL: conversation.avatarURL); map[key(route)] = route }
        return map.values.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        List {
            Section { Toggle("合并为聊天记录", isOn: $merged); Text("已选\(messages.count)条消息，最多100条。逐个接收对象检查并显示真实结果。") .font(.caption).foregroundStyle(.secondary) }
            ForEach(recipients, id: \.self) { route in
                Button { let id = key(route); if !selectedIDs.insert(id).inserted { selectedIDs.remove(id) } } label: {
                    HStack { Text(route.title); Spacer(); Image(systemName: selectedIDs.contains(key(route)) ? "checkmark.circle.fill" : "circle").accessibilityHidden(true) }
                }.frame(minHeight: 44).accessibilityLabel(route.title).accessibilityValue(selectedIDs.contains(key(route)) ? "已选中" : "未选中").accessibilityAddTraits(selectedIDs.contains(key(route)) ? .isSelected : [])
            }
            if !results.isEmpty { Section("处理结果") { ForEach(Array(results.enumerated()), id: \.offset) { Text($0.element) } } }
        }
        .searchable(text: $query, prompt: "搜索好友或群")
        .navigationTitle("转发消息")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.disabled(busy) }; ToolbarItem(placement: .confirmationAction) { Button("发送") { Task { await forward() } }.disabled(busy || selectedIDs.isEmpty) } }
        .disabled(busy).interactiveDismissDisabled(busy)
    }

    /// 收件人身份只由类型与稳定ID组成，重名不合并。
    private func key(_ route: ChatRoute) -> String { (route.kind == .group ? "group:" : "single:") + route.id }

    /// 逐对象确认回执，部分失败保留完整明细并不把未确认对象记成功。
    private func forward() async {
        guard !busy else { return }; busy = true; results = []; defer { busy = false }
        let all = recipients
        for route in all where selectedIDs.contains(key(route)) {
            guard ChatRuntime.shared.isCurrent(context) else { break }
            do {
                let records = try await SDKChatActionsClient().forward(messages, from: context, to: route, merged: merged, onEnqueued: { chat.applyOperationMessages($0, context: context) })
                chat.applyOperationMessages(records, context: context)
                results.append(route.title + (merged ? "：已入队，等待消息回执" : "：\(records.count)条消息已获服务器确认")); selectedIDs.remove(key(route))
            } catch { results.append(route.title + "：" + error.localizedDescription) }
        }
        if selectedIDs.isEmpty { chat.cancelSelection() }
    }
}
