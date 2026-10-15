//
//  ChatMentionPickerView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import SwiftUI

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
                        Text(member.name).foregroundStyle(MessagingTheme.text).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.accessibilityLabel("提及" + member.name)
                }
                if filtered.isEmpty { Text(search.isEmpty ? "暂无可选择的群成员" : "没有匹配的成员").foregroundStyle(MessagingTheme.secondaryText) }
            }
            .searchable(text: $search, prompt: "搜索群成员")
            .navigationTitle("选择@成员").modifier(MessagingPageChrome())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消", action: onCancel).frame(minHeight: 44) } }
        }
    }
}
