//
//  ContactRemarkEditor.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

/// 备注sheet使用编辑副本，不在拼音输入或emoji中间截断内容。
struct ContactRemarkEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var businessStore: ContactsBusinessStore
    let contactID: String
    let sourceGroupID: String?
    private let originalRemark: String
    private let originalDescription: String
    @State private var confirmingDiscard = false
    @State private var remark: String
    @State private var description: String

    /// 编辑草稿只在打开时以最新资料初始化，提交由SDK确认。
    init(businessStore: ContactsBusinessStore, contact: ContactRecord, sourceGroupID: String? = nil) {
        self.businessStore = businessStore; contactID = contact.id; self.sourceGroupID = sourceGroupID
        originalRemark = contact.remarks; originalDescription = contact.description
        _remark = State(initialValue: contact.remarks); _description = State(initialValue: contact.description)
    }

    private var isDirty: Bool { remark != originalRemark || description != originalDescription }

    var body: some View {
        NavigationStack {
            Form {
                Section("备注") {
                    TextField("填写备注", text: $remark).accessibilityLabel("好友备注")
                    Text("\(remark.utf16.count)/50").foregroundStyle(remark.utf16.count > 50 ? ClubTheme.error : Color.secondary)
                }
                Section("描述") {
                    TextEditor(text: $description).frame(minHeight: 120).accessibilityLabel("备注描述")
                    Text("\(description.utf16.count)/200").foregroundStyle(description.utf16.count > 200 ? ClubTheme.error : Color.secondary)
                }
                if let error = businessStore.errorMessage { Text(error).foregroundStyle(ClubTheme.error) }
                if businessStore.isSubmitting { ProgressView("正在保存") }
            }
            .navigationTitle("备注与描述").navigationBarTitleDisplayMode(.inline).navigationBarHidden(false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { if isDirty { confirmingDiscard = true } else { dismiss() } }.disabled(businessStore.isSubmitting) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { if await businessStore.perform(.setRemark(friendID: contactID, remark: remark, description: description), sourceGroupID: sourceGroupID) { dismiss() } } }
                        .disabled(businessStore.isSubmitting || !isDirty || remark.utf16.count > 50 || description.utf16.count > 200 || (!remark.isEmpty && remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
            .interactiveDismissDisabled(businessStore.isSubmitting || isDirty)
            .confirmationDialog("放弃未保存的修改？", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("继续编辑", role: .cancel) {}
                Button("放弃修改", role: .destructive) { dismiss() }
            }
        }
    }
}
