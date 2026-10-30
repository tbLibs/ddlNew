//
//  FriendGroupManagerView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter
import AlertToast

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
                    ForEach(businessStore.groups) { group in
                        HStack(spacing: 8.zoom()) {
                            Button { name = group.displayName; editingID = group.id; showNameEditor = true } label: {
                                VStack(alignment: .leading, spacing: 8.zoom()) {
                                    Text(group.displayName).font(.body.weight(.semibold)).foregroundStyle(MessagingTheme.text)
                                    Text(group.isDefault ? "默认分组 · \(group.members.count)位好友" : "\(group.members.count)位好友").font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                                }.frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: max(44, 72.zoom()))
                            }.buttonStyle(.borderless).accessibilityHint("重命名分组")
                            Menu {
                                Button("重命名") { name = group.displayName; editingID = group.id; showNameEditor = true }
                                if !group.isDefault {
                                    Button("删除分组", role: .destructive) { deleting = group; showDelete = true }
                                }
                                Button("移到前面") { Task { await businessStore.moveGroup(id: group.id, toIndex: 0) } }
                                    .disabled(group.id == businessStore.groups.first?.id)
                                Button("移到后面") { Task { await businessStore.moveGroup(id: group.id, toIndex: businessStore.groups.count - 1) } }
                                    .disabled(group.id == businessStore.groups.last?.id)
                            } label: { Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("管理\(group.displayName)")
                        }.listRowBackground(MessagingTheme.surface)
                    }.onMove(perform: moveGroup)
                } footer: { Text("点击名称可重命名，拖动排序；更多菜单也可调整顺序。") }
                if businessStore.groups.isEmpty && !businessStore.isLoading && businessStore.errorMessage == nil { Text("暂无好友分组").foregroundStyle(MessagingTheme.secondaryText) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(MessagingTheme.surface)
            .frame(maxWidth: 640).frame(maxWidth: .infinity)
            .environment(\.editMode, .constant(.active))
            .listRowBackground(MessagingTheme.surface)
            .modifier(MessagingPageChrome())
            .messagingFeedbackToast(businessStore.errorMessage, isEnabled: !showNameEditor)
            .navigationTitle("分组管理")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("添加") { name = ""; editingID = nil; showNameEditor = true }.frame(minWidth: 44, minHeight: 44) }
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
        .toast(isPresenting: Binding(get: { !showNameEditor && (businessStore.isLoading || businessStore.isSubmitting) }, set: { _ in }), duration: 0, tapToDismiss: false) {
            AlertToast(type: .loading, title: businessStore.isSubmitting ? "正在更新分组" : "正在读取分组",
                       style: .style(backgroundColor: MessagingTheme.toastBackground, titleColor: MessagingTheme.toastText))
        }
    }

    /// 拖动只提交旧接口支持的目标排序值，最终顺序等待服务端刷新。
    private func moveGroup(from offsets: IndexSet, to destination: Int) {
        guard !businessStore.isSubmitting, let source = offsets.first, businessStore.groups.indices.contains(source) else { return }
        let target = destination > source ? destination - 1 : destination
        guard businessStore.groups.indices.contains(target), target != source else { return }
        let group = businessStore.groups[source]
        Task { await businessStore.moveGroup(id: group.id, toIndex: target) }
    }
}
