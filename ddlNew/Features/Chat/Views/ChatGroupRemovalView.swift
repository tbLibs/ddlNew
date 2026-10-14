//
//  ChatGroupRemovalView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI
import UIAdapter

/// 对齐旧版独立移除页：多选、确认及可选清理成员消息，成功才返回设置。
struct ChatGroupRemovalView: View {
    @ObservedObject var store: ChatSettingsStore
    let onRemoved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selection = ChatGroupRemovalSelection()
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var showingConfirmation = false
    @State private var deleteMessages = false
    @State private var submitting = false
    @State private var feedback: String?

    private var userUID: String { UserSessionStore.shared.currentUser?.userUID ?? "" }
    private var candidates: [ChatGroupMember] {
        store.snapshot?.group.map { ChatGroupRemovalSelection.candidates(in: $0, userUID: userUID) } ?? []
    }
    private var candidateIDs: Set<String> { Set(candidates.map(\.id)) }
    private var chosen: [ChatGroupMember] { candidates.filter { selection.selectedIDs.contains($0.id) } }
    private var visible: [ChatGroupMember] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return candidates.filter { text.isEmpty || $0.name.localizedCaseInsensitiveContains(text) }
    }
    private var canSubmit: Bool {
        guard !submitting, !store.busy, let detail = store.snapshot?.group else { return false }
        return selection.action(detail: detail, userUID: userUID, deleteMessages: deleteMessages) != nil
    }

    var body: some View {
        List {
            MessagingSearchField(placeholder: "搜索群成员", text: $query, focus: $searchFocused, identifier: "groupRemoval.search")
                .listRowBackground(MessagingTheme.background).listRowSeparator(.hidden)
            Text("已选择\(chosen.count)人，最多500人")
                .font(.footnote).foregroundStyle(MessagingTheme.secondaryText)
                .listRowBackground(MessagingTheme.background).listRowSeparator(.hidden)
            if visible.isEmpty && !store.busy {
                Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "暂无可移除的群成员" : "无搜索结果")
                    .foregroundStyle(MessagingTheme.secondaryText).frame(maxWidth: .infinity, minHeight: 80.zoom())
                    .listRowBackground(MessagingTheme.surface)
            }
            ForEach(visible) { member in
                Button { toggle(member) } label: { memberRow(member) }
                    .buttonStyle(MessagingRowStyle()).listRowBackground(MessagingTheme.surface)
                    .accessibilityLabel(member.name + "，" + (member.groupRoleTitle.map { $0 + "，" } ?? "") + (selection.selectedIDs.contains(member.id) ? "已选" : "未选"))
                    .accessibilityAddTraits(selection.selectedIDs.contains(member.id) ? .isSelected : [])
            }
            if store.errorMessage != nil {
                Button("刷新成员和权限") { Task { await store.reload() } }.frame(minHeight: 44)
            }
        }
        .listStyle(.plain).scrollDismissesKeyboard(.interactively)
        .disabled(store.busy || submitting)
        .navigationTitle("移除群成员").modifier(MessagingPageChrome())
        .navigationBarBackButtonHidden(submitting)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(chosen.isEmpty ? "完成" : "完成(\(chosen.count))") {
                    searchFocused = false; feedback = nil; deleteMessages = false; showingConfirmation = true
                }
                .buttonStyle(.plain).foregroundStyle(canSubmit ? MessagingTheme.primaryAction : MessagingTheme.secondaryText)
                .frame(minHeight: 44).disabled(!canSubmit)
            }
        }
        .messagingLoadingToast(store.busy && !showingConfirmation, title: "正在更新群成员")
        .messagingFeedbackToast(store.errorMessage ?? feedback, isEnabled: !showingConfirmation)
        .onChange(of: candidateIDs) { _ in selection.reconcile(detail: store.snapshot?.group, userUID: userUID) }
        .sheet(isPresented: $showingConfirmation) { confirmation }
    }

    /// 勾选使用当前权限；搜索切换不会丢失已经选择的其他成员。
    private func toggle(_ member: ChatGroupMember) {
        feedback = nil
        guard let detail = store.snapshot?.group else { return }
        if !selection.toggle(member.id, detail: detail, userUID: userUID) {
            feedback = selection.selectedIDs.count >= 500 ? "最多只能选择500人" : "成员权限已变化，请刷新后重试"
        }
    }

    /// 选择行只有勾选行为，避免进入资料或普通名单。
    private func memberRow(_ member: ChatGroupMember) -> some View {
        HStack(spacing: 12.zoom()) {
            Image(systemName: selection.selectedIDs.contains(member.id) ? "checkmark.circle.fill" : "circle")
                .font(.title3).foregroundStyle(selection.selectedIDs.contains(member.id) ? MessagingTheme.accent : MessagingTheme.secondaryText).accessibilityHidden(true)
            ChatGroupMemberAvatar(member: member, size: 44.zoom())
            VStack(alignment: .leading, spacing: 4.zoom()) {
                Text(member.name).foregroundStyle(MessagingTheme.text)
                ChatGroupMemberRoleBadge(member: member)
            }
            Spacer()
        }.frame(minHeight: max(44, 60.zoom())).contentShape(Rectangle())
    }

    /// 确认弹窗保留旧版删除消息选项，失败后仍可继续或取消，保留选择。
    private var confirmation: some View {
        NavigationStack {
            Form {
                Section("将所选成员移除群聊") {
                    ForEach(chosen) { member in
                        VStack(alignment: .leading, spacing: 4.zoom()) {
                            Text(member.name); ChatGroupMemberRoleBadge(member: member)
                        }
                    }
                }
                Toggle("删除所选成员全部已发消息", isOn: $deleteMessages)
                if chosen.isEmpty { Text("成员或权限已变化，请返回重新选择。").foregroundStyle(MessagingTheme.secondaryText) }
            }
            .disabled(submitting || store.busy)
            .navigationTitle("移除成员").modifier(MessagingPageChrome())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showingConfirmation = false }.frame(minHeight: 44).disabled(submitting || store.busy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认移除", role: .destructive) { Task { await removeSelected() } }
                        .frame(minHeight: 44).disabled(!canSubmit)
                }
            }
            .messagingLoadingToast(submitting || store.busy, title: "正在移除成员")
            .messagingFeedbackToast(store.errorMessage ?? feedback)
        }.interactiveDismissDisabled(submitting || store.busy)
    }

    /// Store和SDK会再次核对最新成员权限；真实受理后返回，回读失败也不能重复提交。
    private func removeSelected() async {
        guard canSubmit, let detail = store.snapshot?.group,
              let action = selection.action(detail: detail, userUID: userUID, deleteMessages: deleteMessages) else { return }
        submitting = true; feedback = nil
        let succeeded = await store.groupAction(action)
        submitting = false
        if succeeded {
            showingConfirmation = false
            onRemoved()
            dismiss()
        }
    }
}
