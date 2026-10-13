//
//  FriendGroupManagerView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

/// 分组管理提供创建、改名、排序和删除，默认组不显示删除操作。
struct FriendGroupManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var businessStore: ContactsBusinessStore
    @State private var name = ""
    @State private var editingID: String?
    @State private var showNameEditor = false
    @State private var deleting: FriendBusinessGroup?
    @State private var showDelete = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(businessStore.groups) { group in
                    HStack {
                        Text(group.name); Spacer(); if group.isDefault { Text("默认").font(.caption).foregroundStyle(.secondary) }
                        Menu {
                            Button("重命名") { name = group.name; editingID = group.id; showNameEditor = true }
                            Button("移到前面") { Task { await businessStore.perform(.reorderGroup(id: group.id, order: (businessStore.groups.first?.order ?? 0) - 1)) } }
                            Button("移到后面") { Task { await businessStore.perform(.reorderGroup(id: group.id, order: (businessStore.groups.last?.order ?? 0) + 1)) } }
                            if !group.isDefault { Button("删除分组", role: .destructive) { deleting = group; showDelete = true } }
                        } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }.accessibilityLabel("管理\(group.name)")
                    }
                }
                if let error = businessStore.errorMessage { Text(error).foregroundStyle(ClubTheme.error) }
                if businessStore.isSubmitting { ProgressView("正在更新分组") }
            }
            .navigationTitle("管理好友分组").navigationBarTitleDisplayMode(.inline).navigationBarHidden(false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("新建") { name = ""; editingID = nil; showNameEditor = true } }
            }
            .disabled(businessStore.isSubmitting)
            .tint(HomeTheme.forest)
            .task { await businessStore.reload() }
            .sheet(isPresented: $showNameEditor) { FriendGroupNameEditor(businessStore: businessStore, groupID: editingID, initialName: name) }
            .alert("删除分组？", isPresented: $showDelete) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) { if let deleting { Task { await businessStore.perform(.deleteGroup(id: deleting.id)) } } }
            } message: { Text("此组内好友会自动移到默认分组，好友关系不会删除。") }
        }
    }
}
