//
//  ChatForwardRecipientView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

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
    @State private var scope = ForwardRecipientScope.recent
    @State private var confirming = false
    @FocusState private var searchFocused: Bool

    /// 完整身份表与可见过滤分离，搜索隐藏的已选对象仍参与确认和发送。
    private var allRecipients: [ChatRoute] {
        var map: [String: ChatRoute] = [:]
        for contact in contacts.contacts where !contact.isDeleted { let route = ChatRoute(id: contact.id, kind: .single, title: contact.displayName, avatarURL: contact.avatar); map[key(route)] = route }
        for group in groups.groups { let route = ChatRoute(id: group.id, kind: .group, title: group.name, avatarURL: group.avatar); map[key(route)] = route }
        for conversation in conversations.conversations where [.single, .group].contains(conversation.kind) { let route = ChatRoute(id: conversation.id, kind: conversation.kind, title: conversation.title, avatarURL: conversation.avatarURL); map[key(route)] = route }
        return Array(map.values).sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }
    private var recipients: [ChatRoute] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty { return allRecipients.filter { $0.title.localizedCaseInsensitiveContains(query) } }
        switch scope {
        case .recent:
            let map = Dictionary(uniqueKeysWithValues: allRecipients.map { (key($0), $0) })
            return conversations.conversations.compactMap { item in
                guard [.single, .group].contains(item.kind) else { return nil }
                return map[(item.kind == .group ? "group:" : "single:") + item.id]
            }
        case .contacts: return allRecipients.filter { route in route.kind == .single && contacts.contacts.contains { !$0.isDeleted && $0.id == route.id } }
        case .groups: return allRecipients.filter { route in route.kind == .group && groups.groups.contains { $0.id == route.id } }
        }
    }
    private var selectedRecipients: [ChatRoute] { allRecipients.filter { selectedIDs.contains(key($0)) } }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12.zoom()) {
                MessagingSearchField(placeholder: "搜索好友或群聊", text: $query, focus: $searchFocused, identifier: "forwardSearch")
                ScrollView(.horizontal, showsIndicators: false) { MessagingTabs(selection: $scope) }
                if messages.count > 1 { Toggle("合并为聊天记录", isOn: $merged).font(.subheadline) }
                Text("已选 \(messages.count) 条消息").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                if messages.count > 100 { Text("一次最多转发 100 条消息，请返回重新选择。").foregroundStyle(MessagingTheme.error).font(.subheadline) }
            }.padding(16.zoom()).background(MessagingTheme.surface)
            MessagingScroll {
                LazyVStack(spacing: 0) {
                    ForEach(recipients, id: \.self) { route in
                        Button { let id = key(route); if !selectedIDs.insert(id).inserted { selectedIDs.remove(id) } } label: {
                            HStack(spacing: 12.zoom()) {
                                Image(systemName: selectedIDs.contains(key(route)) ? "checkmark.circle.fill" : "circle").foregroundStyle(selectedIDs.contains(key(route)) ? MessagingTheme.accent : MessagingTheme.secondaryText).accessibilityHidden(true)
                                ChatSecondaryAvatar(name: route.title, resource: route.avatarURL, isGroup: route.kind == .group)
                                Text(route.title).font(.body).foregroundStyle(MessagingTheme.text).frame(maxWidth: .infinity, alignment: .leading)
                            }.padding(16.zoom()).contentShape(Rectangle())
                        }.buttonStyle(MessagingRowStyle()).accessibilityLabel(route.title).accessibilityValue(selectedIDs.contains(key(route)) ? "已选中" : "未选中").accessibilityAddTraits(selectedIDs.contains(key(route)) ? .isSelected : [])
                        Divider().overlay(MessagingTheme.divider).padding(.leading, 92.zoom())
                    }
                    if recipients.isEmpty { Text(query.isEmpty ? "暂无可选对象，可切换到好友或群聊" : "没有找到匹配的好友或群聊").foregroundStyle(MessagingTheme.secondaryText).padding(24.zoom()) }

                }
            }
        }
        .navigationTitle("选择转发对象").modifier(MessagingPageChrome())
        .messagingLoadingToast(busy, title: "正在发送")
        .messagingFeedbackToast(!busy && !results.isEmpty ? (Array(results.prefix(3)) + (results.count > 3 ? ["另有\(results.count - 3)项处理结果，尚有\(selectedIDs.count)个会话待重试"] : [])).joined(separator: "\n") : nil)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.frame(minHeight: 44).disabled(busy) } }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16.zoom()) {
                Text("已选 \(selectedRecipients.count) 人").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                Spacer()
                Button { searchFocused = false; confirming = true } label: { Text("发送").frame(minWidth: 100.zoom()) }
                    .buttonStyle(MessagingActionButtonStyle()).disabled(busy || selectedRecipients.isEmpty || messages.isEmpty || messages.count > 100)
            }.padding(16.zoom()).background(MessagingTheme.surface)
        }
        .disabled(busy).interactiveDismissDisabled(busy)
        .sheet(isPresented: $confirming) { confirmation }
    }

    /// 旧版选人后展示对象和正文摘要，最后一步确认再调用真实转发。
    private var confirmation: some View {
        NavigationStack {
            MessagingScroll {
                VStack(alignment: .leading, spacing: 16.zoom()) {
                    Text("发送给").font(.headline)
                    ForEach(selectedRecipients, id: \.self) { route in
                        HStack(spacing: 12.zoom()) { ChatSecondaryAvatar(name: route.title, resource: route.avatarURL, isGroup: route.kind == .group); Text(route.title).font(.body) }
                    }
                    MessagingCard { VStack(alignment: .leading, spacing: 8.zoom()) { Text(merged ? "合并转发 \(messages.count) 条消息" : "逐条转发 \(messages.count) 条消息").font(.headline); ForEach(Array(messages.prefix(3))) { item in Text(item.displayText).font(.subheadline).lineLimit(2) }; if messages.count > 3 { Text("还有 \(messages.count - 3) 条消息").font(.caption).foregroundStyle(MessagingTheme.secondaryText) } } }
                }.padding(16.zoom())
            }.navigationTitle("确认转发").modifier(MessagingPageChrome())
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { confirming = false }.frame(minHeight: 44) }; ToolbarItem(placement: .confirmationAction) { Button("发送") { let targets = selectedRecipients; let mergeMessages = merged; confirming = false; Task { await forward(to: targets, merged: mergeMessages) } }.frame(minHeight: 44).disabled(selectedRecipients.isEmpty) } }
        }
    }

    /// 收件人身份只由类型与稳定 ID 组成，重名不合并。
    private func key(_ route: ChatRoute) -> String { (route.kind == .group ? "group:" : "single:") + route.id }

    /// 提交固定确认时的对象及模式，逐对象显示回执；失败对象保留选择便于重试。
    private func forward(to targets: [ChatRoute], merged: Bool) async {
        guard !busy, messages.count <= 100 else { return }; busy = true; results = []; defer { busy = false }
        for route in targets {
            guard ChatRuntime.shared.isCurrent(context) else { results.append("登录状态已变化，请重新进入聊天后转发。"); break }
            do {
                let records = try await SDKChatActionsClient().forward(messages, from: context, to: route, merged: merged, onEnqueued: { chat.applyOperationMessages($0, context: context) })
                guard ChatRuntime.shared.isCurrent(context) else { return }
                chat.applyOperationMessages(records, context: context)
                results.append(route.title + (merged ? "：已入队，等待消息回执" : "：\(records.count)条消息已获服务器确认")); selectedIDs.remove(key(route))
            } catch { results.append(route.title + "：" + error.localizedDescription) }
        }
        if selectedIDs.isEmpty { chat.cancelSelection() }
    }
}

private enum ForwardRecipientScope: String, CaseIterable { case recent = "最近聊天", contacts = "好友", groups = "群聊" }
