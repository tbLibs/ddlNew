//
//  FriendGroupNameEditor.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter
import AlertToast

/// 分组名称编辑留在sheet内等待回执，失败保留输入与目标分组。
struct FriendGroupNameEditor: View {
    @Environment(\.locale) private var localizationLocale
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var businessStore: ContactsBusinessStore
    let groupID: String?
    private let originalName: String
    @State private var name: String
    @State private var confirmingDiscard = false

    /// 当前分组名称只初始化本次编辑草稿，刷新不会覆盖用户输入。
    init(businessStore: ContactsBusinessStore, groupID: String?, initialName: String) {
        self.businessStore = businessStore; self.groupID = groupID; originalName = initialName
        _name = State(initialValue: initialName)
    }

    private var isDirty: Bool { name != originalName }
    private var canSave: Bool {
        !businessStore.isSubmitting && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (groupID == nil || isDirty)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("分组名称")) { TextField(L10n.tr("请输入分组名称"), text: $name).frame(minHeight: 44).accessibilityLabel(L10n.tr("分组名称")).disabled(businessStore.isSubmitting) }
            }
            .listRowBackground(MessagingTheme.surface)
            .navigationTitle(groupID == nil ? L10n.tr("添加分组") : L10n.tr("重命名分组"))
            .modifier(MessagingPageChrome())
        .messagingFeedbackToast(businessStore.errorMessage)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("取消")) { if isDirty { confirmingDiscard = true } else { dismiss() } }.disabled(businessStore.isSubmitting) }
            }
            .safeAreaInset(edge: .bottom) {
                Button { Task { await save() } } label: {
                    Text(L10n.tr("保存")).frame(maxWidth: .infinity)
                }.buttonStyle(MessagingActionButtonStyle())
                    .disabled(!canSave)
                    .padding(16.zoom()).background(MessagingTheme.surface)
            }
            .interactiveDismissDisabled(businessStore.isSubmitting || isDirty)
            .confirmationDialog(L10n.tr("放弃未保存的分组名称？"), isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button(L10n.tr("继续编辑"), role: .cancel) {}
                Button(L10n.tr("放弃修改"), role: .destructive) { dismiss() }
            }
        }
        .toast(isPresenting: Binding(get: { businessStore.isSubmitting }, set: { _ in }), duration: 0, tapToDismiss: false) {
            AlertToast(type: .loading, title: L10n.tr("正在保存"),
                       style: .style(backgroundColor: MessagingTheme.toastBackground, titleColor: MessagingTheme.toastText))
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// 服务端成功后才关闭编辑器，失败时保留原草稿供重试。
    private func save() async {
        let operation = groupID.map { ContactBusinessOperation.renameGroup(id: $0, name: name) } ?? .createGroup(name: name)
        if await businessStore.perform(operation) { dismiss() }
    }
}
