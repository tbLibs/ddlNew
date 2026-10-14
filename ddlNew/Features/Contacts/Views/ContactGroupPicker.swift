//
//  ContactGroupPicker.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

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
                Section {
                    Button { showingCreate = true } label: {
                        Label("添加分组", systemImage: "plus.circle").frame(minHeight: max(44, 54.zoom()))
                    }.disabled(businessStore.isSubmitting)
                }
                Section {
                    ForEach(businessStore.groups) { group in
                        Button { Task { if await businessStore.perform(.moveFriend(friendID: contactID, groupID: group.id), sourceGroupID: sourceGroupID) { dismiss() } } } label: {
                            HStack(spacing: 12.zoom()) {
                                Text(group.name).foregroundStyle(MessagingTheme.text).frame(maxWidth: .infinity, alignment: .leading)
                                if group.members.contains(where: { $0.id == contactID }) {
                                    Image(systemName: "checkmark").foregroundStyle(MessagingTheme.accent).accessibilityHidden(true)
                                }
                            }.frame(minHeight: max(44, 54.zoom()))
                        }
                        .buttonStyle(.borderless)
                        .accessibilityValue(group.members.contains(where: { $0.id == contactID }) ? "当前分组" : "")
                        .disabled(businessStore.isSubmitting)
                    }
                } footer: { Text("选择后将移动到该分组，好友关系不变。") }
                if businessStore.isLoading { ProgressView("正在读取分组") }
                if businessStore.isSubmitting { ProgressView("正在移动分组") }
                if businessStore.groups.isEmpty && !businessStore.isLoading && businessStore.errorMessage == nil { Text("暂无可用分组，可以先添加分组。").foregroundStyle(MessagingTheme.secondaryText) }
                if let error = businessStore.errorMessage { Text(error).foregroundStyle(MessagingTheme.error) }
            }
            .listRowBackground(MessagingTheme.surface)
            .navigationTitle("移动分组")
            .modifier(MessagingPageChrome())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(businessStore.isSubmitting) } }
            .task { await businessStore.reload() }
            .interactiveDismissDisabled(businessStore.isSubmitting)
            .sheet(isPresented: $showingCreate) { FriendGroupNameEditor(businessStore: businessStore, groupID: nil, initialName: "") }
        }
    }
}
