//
//  FriendGroupManagerView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

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
                Section {
                    Button { name = ""; editingID = nil; showNameEditor = true } label: {
                        Label("添加分组", systemImage: "plus.circle").frame(minHeight: max(44, 54.zoom()))
                    }
                }
                Section {
                    ForEach(businessStore.groups) { group in
                        HStack(spacing: 8.zoom()) {
                            if !group.isDefault {
                                Button(role: .destructive) { deleting = group; showDelete = true } label: {
                                    Image(systemName: "minus.circle.fill").frame(minWidth: 44, minHeight: 44)
                                }.buttonStyle(.borderless).accessibilityLabel("删除\(group.name)")
                            }
                            Button { name = group.name; editingID = group.id; showNameEditor = true } label: {
                                VStack(alignment: .leading, spacing: 4.zoom()) {
                                    Text(group.name).foregroundStyle(MessagingTheme.text)
                                    Text(group.isDefault ? "默认分组 · \(group.members.count)位好友" : "\(group.members.count)位好友").font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                                }.frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: max(44, 54.zoom()))
                            }.buttonStyle(.borderless).accessibilityHint("重命名分组")
                            Menu {
                                Button("重命名") { name = group.name; editingID = group.id; showNameEditor = true }
                                Button("移到前面") { Task { await businessStore.perform(.reorderGroup(id: group.id, order: (businessStore.groups.first?.order ?? 0) - 1)) } }
                                Button("移到后面") { Task { await businessStore.perform(.reorderGroup(id: group.id, order: (businessStore.groups.last?.order ?? 0) + 1)) } }
                            } label: { Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("管理\(group.name)")
                        }
                    }.onMove(perform: moveGroup)
                } footer: { Text("点击名称可重命名，拖动排序；更多菜单也可调整顺序。") }
                if businessStore.groups.isEmpty && !businessStore.isLoading && businessStore.errorMessage == nil { Text("暂无好友分组").foregroundStyle(MessagingTheme.secondaryText) }
                if let error = businessStore.errorMessage { Text(error).foregroundStyle(MessagingTheme.error) }
                if let notice = businessStore.notice { Text(notice).foregroundStyle(MessagingTheme.secondaryText) }
                if businessStore.isLoading { ProgressView("正在读取分组") }
                if businessStore.isSubmitting { ProgressView("正在更新分组") }
            }
            .environment(\.editMode, .constant(.active))
            .listRowBackground(MessagingTheme.surface)
            .modifier(MessagingPageChrome())
            .navigationTitle("分组管理")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
            .disabled(businessStore.isSubmitting)
            .interactiveDismissDisabled(businessStore.isSubmitting)
            .task { await businessStore.reload() }
            .sheet(isPresented: $showNameEditor) { FriendGroupNameEditor(businessStore: businessStore, groupID: editingID, initialName: name) }
            .alert("删除分组？", isPresented: $showDelete) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) { if let deleting { Task { await businessStore.perform(.deleteGroup(id: deleting.id)) } } }
            } message: { Text("此组内好友会自动移到默认分组，好友关系不会删除。") }
        }
    }

    /// 拖动只提交旧接口支持的目标排序值，最终顺序等待服务端刷新。
    private func moveGroup(from offsets: IndexSet, to destination: Int) {
        guard !businessStore.isSubmitting, let source = offsets.first, businessStore.groups.indices.contains(source) else { return }
        let target = destination > source ? destination - 1 : destination
        guard businessStore.groups.indices.contains(target), target != source else { return }
        let group = businessStore.groups[source]
        let order = businessStore.groups[target].order
        Task { await businessStore.perform(.reorderGroup(id: group.id, order: order)) }
    }
}
