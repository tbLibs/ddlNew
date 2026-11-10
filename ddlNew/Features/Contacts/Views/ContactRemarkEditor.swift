//
//  ContactRemarkEditor.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter
import AlertToast

/// 备注sheet使用编辑副本，不在拼音输入或emoji中间截断内容。
struct ContactRemarkEditor: View {
    @Environment(\.locale) private var localizationLocale
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var businessStore: ContactsBusinessStore
    let contactID: String
    let sourceGroupID: String?
    private let originalRemark: String
    private let originalDescription: String
    private let onSaved: () async -> Void
    @State private var confirmingDiscard = false
    @State private var completingSave = false
    @State private var remark: String
    @State private var description: String

    /// 编辑草稿只在打开时以最新资料初始化，提交由SDK确认。
    init(businessStore: ContactsBusinessStore, contact: ContactRecord, sourceGroupID: String? = nil, onSaved: @escaping () async -> Void = {}) {
        self.businessStore = businessStore; contactID = contact.id; self.sourceGroupID = sourceGroupID
        self.onSaved = onSaved
        originalRemark = contact.remarks; originalDescription = contact.description
        _remark = State(initialValue: contact.remarks); _description = State(initialValue: contact.description)
    }

    private var isDirty: Bool { remark != originalRemark || description != originalDescription }

    private var isSaving: Bool { businessStore.isSubmitting || completingSave }

    /// 保存和通讯录回读完成前保持禁用与loading，避免结束请求后再次重复提交。
    private func save() async {
        guard !isSaving else { return }
        completingSave = true
        defer { completingSave = false }
        if await businessStore.perform(.setRemark(friendID: contactID, remark: remark, description: description), sourceGroupID: sourceGroupID) {
            await onSaved()
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("设置备注")) {
                    TextField(L10n.tr("请填写备注"), text: $remark).frame(minHeight: 44).accessibilityLabel(L10n.tr("好友备注")).disabled(isSaving)
                    Text("\(remark.utf16.count)/50").font(.caption).foregroundStyle(remark.utf16.count > 50 ? MessagingTheme.error : MessagingTheme.secondaryText)
                    if remark.utf16.count > 50 { Text(L10n.tr("备注最多50字，请缩短后保存。")).font(.caption).foregroundStyle(MessagingTheme.error) }
                }
                Section(L10n.tr("描述")) {
                    TextEditor(text: $description).font(.body).scrollContentBackground(.hidden).frame(minHeight: 160.zoom()).accessibilityLabel(L10n.tr("备注描述")).disabled(isSaving)
                    Text("\(description.utf16.count)/200").font(.caption).foregroundStyle(description.utf16.count > 200 ? MessagingTheme.error : MessagingTheme.secondaryText)
                    if description.utf16.count > 200 { Text(L10n.tr("描述最多200字，请缩短后保存。")).font(.caption).foregroundStyle(MessagingTheme.error) }
                }
            }
            .listRowBackground(MessagingTheme.surface)
            .navigationTitle(L10n.tr("备注与描述"))
            .modifier(MessagingPageChrome())
        .messagingFeedbackToast(businessStore.errorMessage)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("取消")) { if isDirty { confirmingDiscard = true } else { dismiss() } }.disabled(isSaving) }
            }
            .safeAreaInset(edge: .bottom) {
                Button { Task { await save() } } label: {
                    Text(L10n.tr("保存")).frame(maxWidth: .infinity)
                }
                .buttonStyle(MessagingActionButtonStyle())
                .disabled(isSaving || !isDirty || remark.utf16.count > 50 || description.utf16.count > 200 || (!remark.isEmpty && remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                .padding(16.zoom()).background(MessagingTheme.surface)
            }
            .interactiveDismissDisabled(isSaving || isDirty)
            .confirmationDialog(L10n.tr("放弃未保存的修改？"), isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button(L10n.tr("继续编辑"), role: .cancel) {}
                Button(L10n.tr("放弃修改"), role: .destructive) { dismiss() }
            }
        }
        // 提交完成或失败时由Store关闭Toast，提示本身不能中断保存。
        .toast(isPresenting: Binding(get: { isSaving }, set: { _ in }), duration: 0, tapToDismiss: false) {
            AlertToast(type: .loading, title: L10n.tr("正在保存"),
                       style: .style(backgroundColor: MessagingTheme.toastBackground, titleColor: MessagingTheme.toastText))
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
