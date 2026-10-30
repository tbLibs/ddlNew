//
//  ChatMentionPickerView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import SwiftUI
import UIAdapter

/// 成员来自当前群的真实SDK同步，搜索仅筛选当前快照，不构造虚拟成员。
struct ChatMentionPickerView: View {
    let members: [ChatGroupMember]
    let onSelect: (ChatGroupMember) -> Void
    let onCancel: () -> Void
    @State private var search = ""

    private var filtered: [ChatGroupMember] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? members : members.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { member in
                    Button { onSelect(member) } label: {
                        HStack(spacing: 12.zoom()) {
                            VStack(alignment: .leading, spacing: 8.zoom()) {
                                Text(member.name).font(.body.weight(.semibold)).foregroundStyle(MessagingTheme.text)
                                if let role = member.groupRoleTitle {
                                    Text(role).font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                                } else if !member.isDeleted && member.role == 0 {
                                    Text("群成员").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(MessagingTheme.secondaryText).accessibilityHidden(true)
                        }.frame(minHeight: max(44, 64.zoom()))
                    }.listRowBackground(MessagingTheme.surface).accessibilityLabel("提及" + member.name)
                }
                if filtered.isEmpty { Text(search.isEmpty ? "暂无可选择的群成员" : "没有匹配的成员").foregroundStyle(MessagingTheme.secondaryText) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(MessagingTheme.surface)
            .searchable(text: $search, prompt: "搜索群成员")
            .navigationTitle("选择@成员").modifier(MessagingPageChrome())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消", action: onCancel).frame(minHeight: 44) } }
        }
    }
}
