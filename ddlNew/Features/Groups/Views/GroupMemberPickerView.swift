//
//  GroupMemberPickerView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

/// 系统sheet选人，以UID管理最近、分组、搜索与已选列表的联动。
struct GroupMemberPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let contacts: [ContactRecord]
    let preselectedIDs: Set<String>
    let excludedIDs: Set<String>
    let minimum: Int
    let maximum: Int
    let title: String
    let invitationReason: Binding<String>?
    let recentIDs: [String]
    let friendGroups: [FriendBusinessGroup]
    let onConfirm: ([ContactRecord]) -> Void
    let onSubmit: (([ContactRecord]) async -> Bool)?
    let submissionError: String?
    @State private var submitting = false
    @State private var selectedIDs: Set<String>
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var selectionMessage: String?
    @State private var failedSubmission = false
    @State private var filter = GroupMemberPickerFilter.all

    /// 输入为最新候选，编辑勾选作为sheet草稿，预置成员禁止取消。
    init(contacts: [ContactRecord], preselectedIDs: Set<String> = [], excludedIDs: Set<String> = [], minimum: Int = 2, maximum: Int = 200, title: String = "选择好友", invitationReason: Binding<String>? = nil, recentIDs: [String] = [], friendGroups: [FriendBusinessGroup] = [], submissionError: String? = nil, onSubmit: (([ContactRecord]) async -> Bool)? = nil, onConfirm: @escaping ([ContactRecord]) -> Void) {
        self.contacts = contacts; self.preselectedIDs = preselectedIDs; self.excludedIDs = excludedIDs
        self.minimum = minimum; self.maximum = maximum; self.title = title; self.invitationReason = invitationReason
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
            VStack(spacing: 0) {
                selectionHeader
                List {
                    if let invitationReason {
                        Section {
                            Text("本群进群需审核，请说明邀请理由").font(.footnote).foregroundStyle(MessagingTheme.secondaryText)
                            TextField("说明邀请理由", text: invitationReason, axis: .vertical).accessibilityLabel("邀请审核说明").frame(minHeight: 44)
                        }.listRowBackground(MessagingTheme.surface)
                    }
                    if filter == .groups {
                        if friendGroups.isEmpty { empty("暂无好友分组") }
                        ForEach(friendGroups) { group in
                            // 普通标题行避免系统Section额外的顶部留白，紧接候选来源标签。
                            Text(group.displayName).font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                                .frame(minHeight: 24.zoom(), alignment: .leading)
                                .listRowInsets(EdgeInsets(top: 4.zoom(), leading: 16.zoom(), bottom: 4.zoom(), trailing: 16.zoom()))
                                .listRowBackground(MessagingTheme.background).listRowSeparator(.hidden).accessibilityAddTraits(.isHeader)
                            Button { selectGroup(group) } label: {
                                Text(group.members.filter { member in available.contains { $0.id == member.id } }.allSatisfy { selectedIDs.contains($0.id) } ? "取消本组选择" : "选择本组好友")
                                    .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: max(44, 44.zoom())).contentShape(Rectangle())
                            }.buttonStyle(MessagingRowStyle())
                                .listRowInsets(EdgeInsets(top: 0, leading: 16.zoom(), bottom: 0, trailing: 16.zoom()))
                                .listRowBackground(MessagingTheme.surface)
                            ForEach(visible.filter { contact in group.members.contains { $0.id == contact.id } }) { contact in row(contact) }
                        }
                    } else {
                        let records = filter == .recent ? recent : visible
                        if records.isEmpty { empty(query.isEmpty ? (filter == .recent ? "暂无最近联系人" : "暂无可选择的好友") : "无搜索结果") }
                        ForEach(records) { contact in row(contact) }
                    }
                }.listStyle(.plain).scrollDismissesKeyboard(.interactively).disabled(submitting)
            }
            .navigationTitle(title).modifier(MessagingPageChrome())
            .messagingLoadingToast(submitting, title: "正在提交选择")
            .messagingFeedbackToast(failedSubmission ? (submissionError ?? "提交失败，请重试。当前选择已保留。") : selectionMessage)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.frame(minHeight: 44).disabled(submitting) }
                ToolbarItem(placement: .confirmationAction) { Button("完成(\(chosen.count))") { Task { await confirm() } }.frame(minHeight: 44).disabled(submitting || !(minimum...maximum).contains(chosen.count)) }
            }
            .interactiveDismissDisabled(submitting)
        }
    }

    /// 空态区分候选来源与无搜索结果，避免选人列表空白。
    private func empty(_ message: String) -> some View { Text(message).font(.subheadline).foregroundStyle(MessagingTheme.secondaryText).frame(maxWidth: .infinity, minHeight: 100.zoom()).listRowBackground(MessagingTheme.surface).listRowSeparator(.hidden) }

    /// 网络提交失败保留当前勾选，服务端成功后才关闭sheet。
    private func confirm() async {
        guard !submitting else { return }
        if let onSubmit {
            failedSubmission = false; submitting = true
            let completed = await onSubmit(chosen)
            submitting = false
            if completed { dismiss() } else { failedSubmission = true }
        } else { onConfirm(chosen); dismiss() }
    }

    /// 顶部已选可取消普通成员，预选与数量边界持续可见。
    private var selectionHeader: some View {
        VStack(alignment: .leading, spacing: 8.zoom()) {
            MessagingSearchField(placeholder: "搜索好友", text: $query, focus: $searchFocused, identifier: "groupPicker.search")
            Text(preselectedIDs.isEmpty ? "选择至少\(minimum)位好友，最多\(maximum)位。" : "当前好友已选中，请再选择至少\(max(1, minimum - preselectedIDs.count))位好友。")
                .font(.footnote).foregroundStyle(MessagingTheme.secondaryText)
            if !chosen.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12.zoom()) { ForEach(chosen) { contact in
                        Button { toggle(contact.id) } label: {
                            VStack(spacing: 4.zoom()) {
                                ContactRecordAvatar(contact: contact, fileHost: OSSConnectionBootstrap.shared.current?.getFileHost, size: 40.zoom())
                                    .overlay(alignment: .topTrailing) { Image(systemName: preselectedIDs.contains(contact.id) ? "lock.fill" : "xmark.circle.fill").font(.caption).foregroundStyle(MessagingTheme.accent).background(MessagingTheme.surface, in: Circle()).accessibilityHidden(true) }
                                Text(contact.displayName).font(.caption).foregroundStyle(MessagingTheme.text).lineLimit(2)
                            }.frame(width: 64.zoom()).frame(minHeight: 44)
                        }.disabled(preselectedIDs.contains(contact.id) || submitting).accessibilityLabel(preselectedIDs.contains(contact.id) ? contact.displayName + "，已预选" : "取消选择" + contact.displayName)
                    } }
                }
            }
            Picker("候选来源", selection: $filter) { ForEach(GroupMemberPickerFilter.allCases) { item in Text(item.rawValue).tag(item) } }.pickerStyle(.segmented)
        }.padding(.horizontal, 16.zoom()).padding(.top, 16.zoom())
            .padding(.bottom, filter == .groups ? 8.zoom() : 16.zoom()).background(MessagingTheme.surface)
    }

    /// 头像和勾选沿用旧选人列表，所有候选来源共用UID集合。
    private func row(_ contact: ContactRecord) -> some View {
        let selected = selectedIDs.contains(contact.id)
        return Button { toggle(contact.id) } label: {
            HStack(spacing: 12.zoom()) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(selected ? MessagingTheme.accent : MessagingTheme.secondaryText).accessibilityHidden(true)
                ContactRecordAvatar(contact: contact, fileHost: OSSConnectionBootstrap.shared.current?.getFileHost, size: 44.zoom())
                Text(contact.displayName).foregroundStyle(MessagingTheme.text); Spacer()
                if preselectedIDs.contains(contact.id) { Text("已选").font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
            }.padding(.vertical, 8.zoom()).frame(minHeight: max(44, 60.zoom())).contentShape(Rectangle())
        }.buttonStyle(MessagingRowStyle()).listRowBackground(MessagingTheme.surface)
            .disabled(preselectedIDs.contains(contact.id))
            .accessibilityLabel("\(contact.displayName)，\(selected ? "已选" : "未选")")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// 批量选择也逐个验证好友有效性与人数上限。
    private func selectGroup(_ group: FriendBusinessGroup) {
        selectionMessage = nil
        let members = group.members.filter { member in available.contains { $0.id == member.id } }
        if members.allSatisfy({ selectedIDs.contains($0.id) }) {
            selectedIDs.subtract(members.filter { !preselectedIDs.contains($0.id) }.map(\.id)); return
        }
        for member in members where !selectedIDs.contains(member.id) {
            guard chosen.count < maximum else { selectionMessage = "最多只能选择\(maximum)位好友"; break }; selectedIDs.insert(member.id)
        }
    }

    /// 预选成员不能取消，选择到上限后不能继续添加。
    private func toggle(_ id: String) {
        guard !preselectedIDs.contains(id) else { return }
        selectionMessage = nil
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else if chosen.count < maximum { selectedIDs.insert(id) } else { selectionMessage = "最多只能选择\(maximum)位好友" }
    }
}
