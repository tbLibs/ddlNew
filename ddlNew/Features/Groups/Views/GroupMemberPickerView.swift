//
//  GroupMemberPickerView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

/// 系统sheet选人，以UID管理最近、分组、搜索与已选列表的联动。
struct GroupMemberPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let contacts: [ContactRecord]
    let preselectedIDs: Set<String>
    let excludedIDs: Set<String>
    let minimum: Int
    let maximum: Int
    let recentIDs: [String]
    let friendGroups: [FriendBusinessGroup]
    let onConfirm: ([ContactRecord]) -> Void
    let onSubmit: (([ContactRecord]) async -> Bool)?
    let submissionError: String?
    @State private var submitting = false
    @State private var selectedIDs: Set<String>
    @State private var query = ""
    @State private var filter = GroupMemberPickerFilter.all

    /// 输入为最新候选，编辑勾选作为sheet草稿，预置成员禁止取消。
    init(contacts: [ContactRecord], preselectedIDs: Set<String> = [], excludedIDs: Set<String> = [], minimum: Int = 2, maximum: Int = 200, recentIDs: [String] = [], friendGroups: [FriendBusinessGroup] = [], submissionError: String? = nil, onSubmit: (([ContactRecord]) async -> Bool)? = nil, onConfirm: @escaping ([ContactRecord]) -> Void) {
        self.contacts = contacts; self.preselectedIDs = preselectedIDs; self.excludedIDs = excludedIDs
        self.minimum = minimum; self.maximum = maximum
        let validIDs = Set(contacts.filter { $0.userType == 0 && !$0.isDeleted && !excludedIDs.contains($0.id) }.map(\.id))
        var recentSeen = Set<String>()
        self.recentIDs = Array(recentIDs.filter { validIDs.contains($0) && recentSeen.insert($0).inserted }.prefix(50))
        self.friendGroups = friendGroups; self.onConfirm = onConfirm; self.onSubmit = onSubmit; self.submissionError = submissionError; _selectedIDs = State(initialValue: preselectedIDs)
    }

    private var available: [ContactRecord] { GroupMemberSelection(contacts: contacts, preselectedIDs: preselectedIDs, excludedIDs: excludedIDs).available }
    private var chosen: [ContactRecord] { available.filter { selectedIDs.contains($0.id) } }
    private var visible: [ContactRecord] { ContactSorter.sorted(available).filter { query.isEmpty || $0.searchText.localizedCaseInsensitiveContains(query) } }
    private var recent: [ContactRecord] { recentIDs.compactMap { id in visible.first { $0.id == id } } }

    var body: some View {
        NavigationStack {
            List {
                selectionHeader
                if filter == .groups {
                    ForEach(friendGroups) { group in
                        Section(group.name) {
                            Button(group.members.filter { member in available.contains { $0.id == member.id } }.allSatisfy { selectedIDs.contains($0.id) } ? "取消本组选择" : "选择本组好友") { selectGroup(group) }
                            ForEach(visible.filter { contact in group.members.contains { $0.id == contact.id } }) { contact in row(contact) }
                        }
                    }
                } else { ForEach(filter == .recent ? recent : visible) { contact in row(contact) } }
                if submitting { ProgressView("正在提交选择") }
                if let submissionError { Text(submissionError).foregroundStyle(ClubTheme.error) }
            }.disabled(submitting)
            .searchable(text: $query, prompt: "搜索好友")
            .navigationTitle("选择好友").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(submitting) }
                ToolbarItem(placement: .confirmationAction) { Button("确定") { Task { await confirm() } }.disabled(submitting || !(minimum...maximum).contains(chosen.count)) }
            }
            .interactiveDismissDisabled(submitting)
        }
    }

    /// 网络提交失败保留当前勾选，服务端成功后才关闭sheet。
    private func confirm() async {
        guard !submitting else { return }
        if let onSubmit {
            submitting = true
            let completed = await onSubmit(chosen)
            submitting = false
            if completed { dismiss() }
        } else { onConfirm(chosen); dismiss() }
    }

    /// 顶部已选可取消普通成员，预选与数量边界持续可见。
    private var selectionHeader: some View {
        Section {
            Text(preselectedIDs.isEmpty ? "选择至少\(minimum)位好友，最多\(maximum)位。" : "已包含当前好友，请再选择至少\(max(1, minimum - preselectedIDs.count))位好友。")
                .foregroundStyle(.secondary)
            Text("已选 \(chosen.count) 位").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack { ForEach(chosen) { contact in
                    Button { toggle(contact.id) } label: { Label(contact.displayName, systemImage: preselectedIDs.contains(contact.id) ? "lock.fill" : "xmark.circle.fill").font(.caption).padding(8) }.disabled(preselectedIDs.contains(contact.id))
                } }
            }
            Picker("候选来源", selection: $filter) { ForEach(GroupMemberPickerFilter.allCases) { item in Text(item.rawValue).tag(item) } }.pickerStyle(.segmented)
        }
    }

    /// 行勾选共用UID集合，切换候选来源不重置选择。
    private func row(_ contact: ContactRecord) -> some View {
        Button { toggle(contact.id) } label: {
            HStack {
                Text(contact.displayName).foregroundStyle(.primary); Spacer()
                Image(systemName: selectedIDs.contains(contact.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(selectedIDs.contains(contact.id) ? ClubTheme.darkTeal : ClubTheme.secondary)
            }.frame(minHeight: 32)
        }.disabled(preselectedIDs.contains(contact.id)).accessibilityLabel("\(contact.displayName)，\(selectedIDs.contains(contact.id) ? "已选" : "未选")")
    }

    /// 批量选择也逐个验证好友有效性与人数上限。
    private func selectGroup(_ group: FriendBusinessGroup) {
        let members = group.members.filter { member in available.contains { $0.id == member.id } }
        if members.allSatisfy({ selectedIDs.contains($0.id) }) {
            selectedIDs.subtract(members.filter { !preselectedIDs.contains($0.id) }.map(\.id)); return
        }
        for member in members where !selectedIDs.contains(member.id) {
            guard chosen.count < maximum else { break }; selectedIDs.insert(member.id)
        }
    }

    /// 预选成员不能取消，选择到上限后不能继续添加。
    private func toggle(_ id: String) {
        guard !preselectedIDs.contains(id) else { return }
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else if chosen.count < maximum { selectedIDs.insert(id) }
    }
}
