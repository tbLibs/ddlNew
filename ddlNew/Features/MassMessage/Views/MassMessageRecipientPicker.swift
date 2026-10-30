//
//  MassMessageRecipientPicker.swift
//  ddlNew
//
//  Created by taobo on 2026/10/23.
//

import SwiftUI
import UIAdapter

struct MassMessageRecipientPicker: View {
    @Binding var selection: [MassMessageRecipient]
    @ObservedObject private var contacts = LoginSessionService.shared.contacts
    @ObservedObject private var groups = LoginSessionService.shared.groups
    @ObservedObject private var conversations = LoginSessionService.shared.conversations
    @ObservedObject private var business = LoginSessionService.shared.contactBusiness
    @Environment(\.dismiss) private var dismiss
    @State private var selected: [String: MassMessageRecipient]
    @State private var query = ""
    @State private var scope = MassRecipientScope.recent
    @State private var selectedOnly = false
    @FocusState private var focused: Bool

    init(selection: Binding<[MassMessageRecipient]>) {
        _selection = selection
        _selected = State(initialValue: Dictionary(selection.wrappedValue.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new }))
    }
    private var all: [MassMessageRecipient] {
        var map: [String: MassMessageRecipient] = [:]
        for contact in contacts.contacts where !contact.isDeleted && contact.userType == 0 {
            let value = recipient(contact); map[value.id] = value
        }
        for group in groups.groups {
            let value = MassMessageRecipient(uid: group.id, isGroup: true, name: group.name, avatar: group.avatar); map[value.id] = value
        }
        return map.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var sections: [MassRecipientSection] {
        if selectedOnly { return [.init(id: "selected", title: "已选对象", values: filtered(Array(selected.values).sorted { $0.name < $1.name }))] }
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [.init(id: "search", title: "搜索结果", values: filtered(all))] }
        switch scope {
        case .recent:
            let map = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
            var seen = Set<String>()
            let values = conversations.conversations.compactMap { conversation -> MassMessageRecipient? in
                guard [.single, .group].contains(conversation.kind) else { return nil }
                let key = "\(conversation.kind == .group ? 1 : 0):\(conversation.id)"
                guard seen.insert(key).inserted else { return nil }
                return map[key]
            }
            return [.init(id: "recent", title: "最近聊天", values: values)]
        case .groups: return [.init(id: "groups", title: "群聊", values: all.filter(\.isGroup))]
        case .contacts:
            let valid = Set(all.filter { !$0.isGroup }.map(\.uid))
            let result = business.groups.map { group in
                MassRecipientSection(id: group.id, title: group.displayName, values: unique(group.members.filter { valid.contains($0.id) }.map(recipient)))
            }
            let covered = Set(result.flatMap(\.values).map(\.uid))
            let remainder = all.filter { !$0.isGroup && !covered.contains($0.uid) }
            return result + (remainder.isEmpty ? [] : [.init(id: "other", title: "其他好友", values: remainder)])
        }
    }
    private var visible: [MassMessageRecipient] { sections.flatMap(\.values) }
    private var allSelected: Bool { !visible.isEmpty && visible.allSatisfy { selected[$0.id] != nil } }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12.zoom()) {
                MessagingSearchField(placeholder: "搜索好友或群聊", text: $query, focus: $focused, identifier: "massRecipientSearch")
                ScrollView(.horizontal, showsIndicators: false) { MessagingTabs(selection: $scope) }
                HStack {
                    Button(selectedOnly ? "返回列表" : "查看已选（\(selected.count)）") { selectedOnly.toggle() }.frame(minHeight: 44)
                    Spacer()
                    Button(allSelected ? "取消全选" : "全选当前列表") { toggleAll() }.frame(minHeight: 44).disabled(visible.isEmpty)
                }.font(.subheadline)
            }.padding(.horizontal, 16.zoom()).padding(.top, 12.zoom()).background(MessagingTheme.surface)
            List {
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.values) { value in
                            Button { toggle(value) } label: {
                                HStack(spacing: 12.zoom()) {
                                    Image(systemName: selected[value.id] == nil ? "circle" : "checkmark.circle.fill")
                                        .foregroundStyle(selected[value.id] == nil ? MessagingTheme.secondaryText : MessagingTheme.accent).accessibilityHidden(true)
                                    ChatSecondaryAvatar(name: value.name, resource: value.avatar, isGroup: value.isGroup)
                                    VStack(alignment: .leading, spacing: 4.zoom()) {
                                        Text(value.name).font(.body).foregroundStyle(MessagingTheme.text)
                                        if value.isGroup { Text("群聊").font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.padding(.vertical, 6.zoom()).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel(value.name + (value.isGroup ? "，群聊" : "，好友"))
                                .accessibilityValue(selected[value.id] == nil ? "未选中" : "已选中")
                                .accessibilityAddTraits(selected[value.id] == nil ? [] : .isSelected)
                                .listRowBackground(MessagingTheme.surface)
                        }
                    }.textCase(nil)
                }
                if visible.isEmpty { Text(selectedOnly ? "还没有选择接收对象" : "暂无匹配对象，可切换分类或修改搜索").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText).padding(.vertical, 24.zoom()) }
            }.listStyle(.plain)
        }.navigationTitle("选择接收对象").modifier(MessagingPageChrome())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.frame(minHeight: 44) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成（\(selected.count)）") { let available = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) }); selection = selected.keys.compactMap { available[$0] }.sorted { $0.id < $1.id }; dismiss() }
                        .buttonStyle(.plain).foregroundStyle(MessagingTheme.accent)
                        .frame(minHeight: 44)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("已选 \(selected.count) 个接收对象").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(16.zoom()).background(MessagingTheme.surface)
            }
            .task { await contacts.reload(); await groups.reload(); await business.reload() }
            .messagingFeedbackToast(contacts.errorMessage ?? groups.errorMessage ?? business.errorMessage)
    }
    private func unique(_ values: [MassMessageRecipient]) -> [MassMessageRecipient] {
        var seen = Set<String>(); return values.filter { seen.insert($0.id).inserted }
    }
    private func recipient(_ contact: ContactRecord) -> MassMessageRecipient { MassMessageRecipient(uid: contact.id, isGroup: false, name: contact.displayName, avatar: contact.avatar) }
    private func filtered(_ values: [MassMessageRecipient]) -> [MassMessageRecipient] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? values : values.filter { $0.name.localizedCaseInsensitiveContains(text) || $0.uid.localizedCaseInsensitiveContains(text) }
    }
    private func toggle(_ value: MassMessageRecipient) { if selected[value.id] == nil { selected[value.id] = value } else { selected[value.id] = nil } }
    private func toggleAll() { let remove = allSelected; for value in visible { selected[value.id] = remove ? nil : value } }
}

private enum MassRecipientScope: String, CaseIterable { case recent = "最近聊天", contacts = "好友分组", groups = "群聊" }
private struct MassRecipientSection: Identifiable { let id: String; let title: String; let values: [MassMessageRecipient] }
