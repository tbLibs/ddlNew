//
//  ContactsRecipientPickerView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

/// 名片与二维码在同一真实接收人sheet提交，逐目标保留失败结果。
struct ContactsRecipientPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var contacts = LoginSessionService.shared.contacts
    @ObservedObject private var groups = LoginSessionService.shared.groups
    let content: ContactsShareContent
    @State private var selected = Set<String>()
    @State private var query = ""
    @State private var sending = false
    @State private var message: String?
    private let service = ChatShareService()

    private var recipients: [ChatRoute] {
        contacts.contacts.filter { !$0.isDeleted }.map { ChatRoute(id: $0.id, kind: .single, title: $0.displayName, avatarURL: $0.avatar) }
        + groups.groups.map { ChatRoute(id: $0.id, kind: .group, title: $0.name, avatarURL: $0.avatar) }
    }
    private var chosen: [ChatRoute] { recipients.filter { selected.contains(key($0)) } }

    var body: some View {
        NavigationStack {
            List {
                Section("好友") { ForEach(contacts.contacts.filter { !$0.isDeleted && (query.isEmpty || $0.searchText.localizedCaseInsensitiveContains(query)) }) { contact in
                    recipient(ChatRoute(id: contact.id, kind: .single, title: contact.displayName, avatarURL: contact.avatar))
                } }
                Section("群聊") { ForEach(groups.groups.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { group in
                    recipient(ChatRoute(id: group.id, kind: .group, title: group.name, avatarURL: group.avatar))
                } }
                if let message { Text(message).foregroundStyle(.secondary) }
                if sending { ProgressView("正在提交分享") }
            }
            .searchable(text: $query, prompt: "选择接收人")
            .navigationTitle("分享给好友或群聊").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(sending) }
                ToolbarItem(placement: .confirmationAction) { Button("分享(\(chosen.count))") { Task { await send() } }.disabled(sending || chosen.isEmpty) }
            }
            .tint(HomeTheme.forest)
            .interactiveDismissDisabled(sending)
        }
    }

    /// 选择以会话ID与类型为稳定身份，跨搜索保持选中。
    private func recipient(_ route: ChatRoute) -> some View {
        Button { if selected.contains(key(route)) { selected.remove(key(route)) } else if chosen.count < 100 { selected.insert(key(route)) } } label: {
            HStack { Text(route.title).foregroundStyle(.primary); Spacer(); Image(systemName: selected.contains(key(route)) ? "checkmark.circle.fill" : "circle").foregroundStyle(HomeTheme.forest) }.frame(minHeight: 32)
        }.disabled(sending).accessibilityLabel(route.title)
            .accessibilityValue(selected.contains(key(route)) ? "已选" : "未选")
            .accessibilityAddTraits(selected.contains(key(route)) ? .isSelected : [])
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
