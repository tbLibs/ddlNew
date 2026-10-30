//
//  ContactGroupPicker.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter
import AlertToast

/// 移动分组只提交SDK确认的分组ID。
struct ContactGroupPicker: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var businessStore: ContactsBusinessStore
    let contactID: String
    var sourceGroupID: String? = nil
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            List {
                Text("选择分组后立即移动").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                    .padding(.top, 16.zoom()).listRowSeparator(.hidden).listRowBackground(MessagingTheme.surface)
                Section {
                    ForEach(businessStore.groups) { group in
                        Button { Task { if await businessStore.perform(.moveFriend(friendID: contactID, groupID: group.id), sourceGroupID: sourceGroupID) { dismiss() } } } label: {
                            HStack(spacing: 12.zoom()) {
                                Text(group.displayName).font(.body.weight(.semibold)).foregroundStyle(MessagingTheme.text).frame(maxWidth: .infinity, alignment: .leading)
                                if group.members.contains(where: { $0.id == contactID }) {
                                    Image(systemName: "checkmark").foregroundStyle(MessagingTheme.accent).accessibilityHidden(true)
                                }
                            }.frame(minHeight: max(44, 68.zoom()))
                        }
                        .buttonStyle(.borderless)
                        .listRowBackground(MessagingTheme.surface)
                        .accessibilityValue(group.members.contains(where: { $0.id == contactID }) ? "当前分组" : "")
                        .disabled(businessStore.isSubmitting)
                    }
                }
                Button { showingCreate = true } label: {
                    Label("添加分组", systemImage: "plus").frame(minHeight: max(44, 54.zoom()))
                }.disabled(businessStore.isSubmitting).listRowBackground(MessagingTheme.surface)
                if businessStore.groups.isEmpty && !businessStore.isLoading && businessStore.errorMessage == nil { Text("暂无可用分组，可以先添加分组。").foregroundStyle(MessagingTheme.secondaryText) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(MessagingTheme.surface)
            .frame(maxWidth: 640).frame(maxWidth: .infinity)
            .listRowBackground(MessagingTheme.surface)
            .navigationTitle("移动分组")
            .modifier(MessagingPageChrome())
            .messagingFeedbackToast(businessStore.errorMessage)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(businessStore.isSubmitting) } }
            .task { await businessStore.reload() }
            .interactiveDismissDisabled(businessStore.isSubmitting)
            .sheet(isPresented: $showingCreate) { FriendGroupNameEditor(businessStore: businessStore, groupID: nil, initialName: "") }
        }
        // 添加分组子页拥有自己的提交提示，避免两个sheet同时展示Toast。
        .toast(isPresenting: Binding(get: { !showingCreate && (businessStore.isLoading || businessStore.isSubmitting) }, set: { _ in }), duration: 0, tapToDismiss: false) {
            AlertToast(type: .loading, title: businessStore.isSubmitting ? "正在移动分组" : "正在加载",
                       style: .style(backgroundColor: MessagingTheme.toastBackground, titleColor: MessagingTheme.toastText))
        }
    }
}
