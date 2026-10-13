//
//  ChatGroupNoticesView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

struct ChatGroupNoticesView: View {
    let route: ChatRoute
    @StateObject private var store = ChatNoticesStore()
    @State private var showEditor = false
    @State private var selected: ChatGroupNotice?
    @State private var input = ""
    @State private var pinned = false
    @State private var sendMessage = false
    @State private var confirmDelete: ChatGroupNotice?
    @State private var role = 0
    @State private var confirmDiscard = false
    private var editorDirty: Bool { input != (selected?.content ?? "") || pinned != (selected?.pinned ?? false) || sendMessage }

    var body: some View {
        List {
            if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
            if store.notices.isEmpty && !store.busy { Text("暂无群公告").foregroundStyle(.secondary) }
            ForEach(store.notices) { notice in
                NavigationLink {
                    ScrollView { VStack { Text(store.detail?.id == notice.id ? store.detail?.content ?? notice.content : notice.content).frame(maxWidth: .infinity, alignment: .leading); if let error = store.errorMessage { Text(error).foregroundStyle(.red) } }.padding() }
                        .navigationTitle("群公告").task { await store.read(notice) }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        if notice.pinned { Label("置顶公告", systemImage: "pin.fill").font(.caption).foregroundStyle(.secondary) }
                        Text(notice.content).lineLimit(3)
                        Text(notice.timestamp).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .contextMenu {
                    if role > 0 {
                        Button("编辑") { selected = notice; input = notice.content; pinned = notice.pinned; sendMessage = false; showEditor = true }
                        Button("删除公告", role: .destructive) { confirmDelete = notice }
                    }
                }
            }
            if store.hasMore { Button("加载更多") { Task { await store.loadMore() } }.disabled(store.busy) }
        }
        .navigationTitle("群公告")
        .toolbar { if role > 0 { Button("发布") { selected = nil; input = ""; pinned = false; sendMessage = false; showEditor = true } } }
        .task {
            guard let context = ChatRuntime.shared.context(for: route) else { return }
            let client = SDKChatSettingsClient()
            role = (try? await client.load(context: context).group?.role) ?? 0; client.close()
            registerCleanup()
            await store.open(context)
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                Form { TextEditor(text: $input).frame(minHeight: 220).accessibilityLabel("公告正文"); Toggle("置顶公告", isOn: $pinned); Toggle("作为群消息发送", isOn: $sendMessage); if let error = store.errorMessage { Text(error).foregroundStyle(.red) } }
                    .navigationTitle(selected == nil ? "发布公告" : "编辑公告")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { if editorDirty { confirmDiscard = true } else { showEditor = false } }.disabled(store.busy) }; ToolbarItem(placement: .confirmationAction) { Button("保存") { Task { if await store.save(selected, content: input, pinned: pinned, sendMessage: sendMessage) { showEditor = false } } }.disabled(store.busy || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
            }.interactiveDismissDisabled(store.busy || editorDirty)
             .confirmationDialog("放弃公告修改？", isPresented: $confirmDiscard, titleVisibility: .visible) { Button("放弃修改", role: .destructive) { showEditor = false } }
        }
        .confirmationDialog("删除群公告", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }), titleVisibility: .visible) {
            if let notice = confirmDelete { Button("删除所有成员可见的公告", role: .destructive) { Task { _ = await store.save(notice, content: notice.content, pinned: notice.pinned, deleting: true) }; confirmDelete = nil } }
        }
    }
    /// 公告页退出身份时停止SDK等待，不强持有整个视图。
    private func registerCleanup() { let notices = store; ChatRuntime.shared.registerCleanup(owner: notices, conversationID: route.id) { [weak notices] in notices?.close() } }
}
