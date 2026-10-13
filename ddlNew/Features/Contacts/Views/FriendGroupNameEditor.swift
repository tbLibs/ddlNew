//
//  FriendGroupNameEditor.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

/// 分组名称编辑留在sheet内等待回执，失败保留输入与目标分组。
struct FriendGroupNameEditor: View {
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
    var body: some View {
        NavigationStack {
            Form {
                Section("分组名称") { TextField("分组名称", text: $name).accessibilityLabel("分组名称").disabled(businessStore.isSubmitting) }
                if businessStore.isSubmitting { ProgressView("正在保存分组") }
                if let error = businessStore.errorMessage { Text(error).foregroundStyle(ClubTheme.error) }
            }
            .navigationTitle(groupID == nil ? "新建分组" : "重命名分组").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { if isDirty { confirmingDiscard = true } else { dismiss() } }.disabled(businessStore.isSubmitting) }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { await save() } }.disabled(businessStore.isSubmitting || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (groupID != nil && !isDirty)) }
            }
            .tint(HomeTheme.forest)
            .interactiveDismissDisabled(businessStore.isSubmitting || isDirty)
            .confirmationDialog("放弃未保存的分组名称？", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("继续编辑", role: .cancel) {}
                Button("放弃修改", role: .destructive) { dismiss() }
            }
        }
    }

    /// 服务端成功后才关闭编辑器，失败时保留原草稿供重试。
    private func save() async {
        let operation = groupID.map { ContactBusinessOperation.renameGroup(id: $0, name: name) } ?? .createGroup(name: name)
        if await businessStore.perform(operation) { dismiss() }
    }
}
