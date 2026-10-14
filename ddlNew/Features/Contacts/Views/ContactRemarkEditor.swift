//
//  ContactRemarkEditor.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

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
                Section("设置备注") {
                    TextField("请填写备注", text: $remark).frame(minHeight: 44).accessibilityLabel("好友备注").disabled(businessStore.isSubmitting)
                    Text("\(remark.utf16.count)/50").font(.caption).foregroundStyle(remark.utf16.count > 50 ? MessagingTheme.error : MessagingTheme.secondaryText)
                    if remark.utf16.count > 50 { Text("备注最多50字，请缩短后保存。").font(.caption).foregroundStyle(MessagingTheme.error) }
                }
                Section("描述") {
                    TextEditor(text: $description).font(.body).scrollContentBackground(.hidden).frame(minHeight: 160.zoom()).accessibilityLabel("备注描述").disabled(businessStore.isSubmitting)
                    Text("\(description.utf16.count)/200").font(.caption).foregroundStyle(description.utf16.count > 200 ? MessagingTheme.error : MessagingTheme.secondaryText)
                    if description.utf16.count > 200 { Text("描述最多200字，请缩短后保存。").font(.caption).foregroundStyle(MessagingTheme.error) }
                }
                if let error = businessStore.errorMessage { Text(error).foregroundStyle(MessagingTheme.error) }
                if businessStore.isSubmitting { ProgressView("正在保存") }
            }
            .listRowBackground(MessagingTheme.surface)
            .navigationTitle("备注与描述")
            .modifier(MessagingPageChrome())
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { if isDirty { confirmingDiscard = true } else { dismiss() } }.disabled(businessStore.isSubmitting) }
            }
            .safeAreaInset(edge: .bottom) {
                Button { Task { if await businessStore.perform(.setRemark(friendID: contactID, remark: remark, description: description), sourceGroupID: sourceGroupID) { dismiss() } } } label: {
                    Text(businessStore.isSubmitting ? "正在保存" : "保存").frame(maxWidth: .infinity).frame(minHeight: max(44, 50.zoom()))
                }
                .buttonStyle(.borderedProminent).tint(MessagingTheme.primaryAction)
                .disabled(businessStore.isSubmitting || !isDirty || remark.utf16.count > 50 || description.utf16.count > 200 || (!remark.isEmpty && remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                .padding(16.zoom()).background(MessagingTheme.surface)
            }
            .interactiveDismissDisabled(businessStore.isSubmitting || isDirty)
            .confirmationDialog("放弃未保存的修改？", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("继续编辑", role: .cancel) {}
                Button("放弃修改", role: .destructive) { dismiss() }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
