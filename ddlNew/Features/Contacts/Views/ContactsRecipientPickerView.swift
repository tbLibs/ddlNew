//
//  ContactsRecipientPickerView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

/// 名片与二维码在同一真实接收人sheet提交，逐目标保留失败结果。
struct ContactsRecipientPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var contacts = LoginSessionService.shared.contacts
    @ObservedObject private var groups = LoginSessionService.shared.groups
    let content: ContactsShareContent
    @State private var selected = Set<String>()
    @State private var query = ""
    @State private var sending = false
    @State private var confirmingShare = false
    @FocusState private var searchFocused: Bool
    @State private var message: String?
    private let service = ChatShareService()

    private var recipients: [ChatRoute] {
        contacts.contacts.filter { !$0.isDeleted }.map { ChatRoute(id: $0.id, kind: .single, title: $0.displayName, avatarURL: $0.avatar) }
        + groups.groups.map { ChatRoute(id: $0.id, kind: .group, title: $0.name, avatarURL: $0.avatar) }
    }
    private var chosen: [ChatRoute] { recipients.filter { selected.contains(key($0)) } }
    private var hasSearchResults: Bool {
        contacts.contacts.contains { !$0.isDeleted && $0.searchText.localizedCaseInsensitiveContains(query) }
            || groups.groups.contains { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                MessagingSearchField(placeholder: "搜索好友或群聊", text: $query, focus: $searchFocused, identifier: "contactShareSearch")
                    .listRowSeparator(.hidden).listRowBackground(MessagingTheme.background)
                Section("好友") { ForEach(contacts.contacts.filter { !$0.isDeleted && (query.isEmpty || $0.searchText.localizedCaseInsensitiveContains(query)) }) { contact in
                    recipient(ChatRoute(id: contact.id, kind: .single, title: contact.displayName, avatarURL: contact.avatar))
                } }
                Section("群聊") { ForEach(groups.groups.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { group in
                    recipient(ChatRoute(id: group.id, kind: .group, title: group.name, avatarURL: group.avatar))
                } }
                if recipients.isEmpty { Text("暂无可分享的好友或群聊").foregroundStyle(MessagingTheme.secondaryText) }
                else if !query.isEmpty && !hasSearchResults { Text("没有匹配的接收人").foregroundStyle(MessagingTheme.secondaryText) }
                if let message { Text(message).foregroundStyle(MessagingTheme.secondaryText) }
                if sending { ProgressView("正在提交分享") }
            }
            .listStyle(.plain)
            .modifier(MessagingPageChrome())
            .navigationTitle("选择接收人")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(sending) }
                ToolbarItem(placement: .confirmationAction) { Button("分享(\(chosen.count))") { searchFocused = false; confirmingShare = true }.disabled(sending || chosen.isEmpty) }
            }
            .confirmationDialog("分享给\(chosen.count)个会话？", isPresented: $confirmingShare, titleVisibility: .visible) {
                Button("分享") { Task { await send() } }
                Button("取消", role: .cancel) {}
            } message: { Text(chosen.map(\.title).joined(separator: "、")) }
            .safeAreaInset(edge: .bottom) {
                Text("已选\(chosen.count)个会话，最多100个").font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(16.zoom()).background(MessagingTheme.surface)
            }
            .interactiveDismissDisabled(sending)
        }
    }

    /// 选择以会话ID与类型为稳定身份，跨搜索保持选中。
    private func recipient(_ route: ChatRoute) -> some View {
        Button { if selected.contains(key(route)) { selected.remove(key(route)) } else if chosen.count < 100 { selected.insert(key(route)) } else { message = "最多选择100个会话，请先取消部分选择。" } } label: {
            HStack(spacing: 12.zoom()) {
                Image(systemName: selected.contains(key(route)) ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(selected.contains(key(route)) ? MessagingTheme.accent : MessagingTheme.secondaryText).accessibilityHidden(true)
                recipientAvatar(route)
                Text(route.title).font(.body).foregroundStyle(MessagingTheme.text).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.vertical, 8.zoom()).frame(minHeight: max(44, 64.zoom())).contentShape(Rectangle())
        }.buttonStyle(.borderless).listRowBackground(MessagingTheme.surface).disabled(sending).accessibilityLabel(route.title)
            .accessibilityValue(selected.contains(key(route)) ? "已选" : "未选")
            .accessibilityAddTraits(selected.contains(key(route)) ? .isSelected : [])
    }

    /// 接收人沿用联系人和群头像组件，共享当前文件节点及缓存策略。
    @ViewBuilder private func recipientAvatar(_ route: ChatRoute) -> some View {
        if route.kind == .group, let group = groups.groups.first(where: { $0.id == route.id }) {
            GroupRecordAvatar(group: group, fileHost: OSSConnectionBootstrap.shared.current?.getFileHost)
        } else if let contact = contacts.contacts.first(where: { $0.id == route.id }) {
            ContactRecordAvatar(contact: contact, fileHost: OSSConnectionBootstrap.shared.current?.getFileHost, size: 48.zoom())
        }
    }

    /// 选择身份只使用类型和稳定会话ID，昵称头像变化不会创建重复接收人。
    private func key(_ route: ChatRoute) -> String { "\(route.kind == .group ? "group" : "single")|\(route.id)" }

    /// 每个目标由聊天服务核对权限并真实发送，切会话后不展示旧结果。
    private func send() async {
        guard !sending else { return }; sending = true; message = nil
        let revision = ChatRuntime.shared.revision
        var submitted = Set<String>(), failures: [String] = []
        for route in chosen {
            guard ChatRuntime.shared.revision == revision else { sending = false; return }
            do {
                switch content {
                case .contact(let contact, let sourceGroupID):
                    guard await ContactsBusinessStore.shared.checkGroupAccess(sourceGroupID) else { throw ContactBusinessError.invalidInput("当前群不允许分享成员名片") }
                    try await service.sendContactCard(contact: contact, to: route)
                case .image(let data): try await service.sendImage(data: data, to: route)
                }
                submitted.insert(key(route))
            } catch { failures.append("\(route.title)：\(error.localizedDescription)") }
        }
        guard ChatRuntime.shared.revision == revision else { sending = false; return }
        selected.subtract(submitted); sending = false
        message = failures.isEmpty ? "分享已提交，发送状态请在对应聊天中查看。" : "已提交\(submitted.count)个会话。\(failures.joined(separator: "；"))"
    }
}
