//
//  MassMessageView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/23.
//

import SwiftUI
import UIAdapter

struct MassMessageView: View {
    let route: MassMessageRoute
    var body: some View {
        Group {
            if let context = ChatRuntime.shared.context(for: ChatRoute(id: route.id, kind: .massMessage, title: "群发助手", avatarURL: "")) {
                MassMessageHistoryView(context: context)
            } else {
                Text("登录状态已变化，请返回后重新进入").foregroundStyle(MessagingTheme.secondaryText).padding()
            }
        }.navigationTitle("群发助手").modifier(MessagingPageChrome()).toolbar(.hidden, for: .tabBar)
    }
}

private struct MassMessageDraftRequest: Identifiable {
    let id = UUID()
    let original: MassMessageRecord?
}

private struct MassMessageHistoryView: View {
    @StateObject private var store: MassMessageStore
    @ObservedObject private var authority = UserRoleAuthorityStore.shared
    @State private var draft: MassMessageDraftRequest?
    @State private var pendingDelete: MassMessageRecord?
    @State private var gallery: ChatPhotoBrowserRequest?
    @State private var file: ChatMessageRecord?
    @State private var didLoad = false
    @State private var sent = false
    private var allowed: Bool { authority.current?.allows("groupHairAssistant") == true }

    init(context: ChatContext) { _store = StateObject(wrappedValue: MassMessageStore(context: context)) }

    var body: some View {
        List {
            Section {
                Label("将同一条消息发送给多个好友或群聊", systemImage: "paperplane")
                    .font(.subheadline).foregroundStyle(MessagingTheme.secondaryText).padding(.vertical, 4.zoom())
            }
            if store.records.isEmpty && !store.loading {
                Section {
                    VStack(spacing: 12.zoom()) {
                        Image(systemName: "paperplane.circle").font(.largeTitle).foregroundStyle(MessagingTheme.accent).accessibilityHidden(true)
                        Text(store.errorMessage == nil ? "还没有群发记录" : "暂时无法加载记录").font(.headline)
                        Text(store.errorMessage == nil ? "新建一条群发消息，发送结果会显示在这里。" : "请下拉刷新，或轻点重试。").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                        if store.errorMessage != nil { Button("重试") { Task { await store.reload() } }.frame(minHeight: 44) }
                    }.frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.vertical, 24.zoom())
                }
            }
            ForEach(store.records) { record in
                Section {
                    VStack(alignment: .leading, spacing: 12.zoom()) {
                        if !record.label.isEmpty {
                            Label(record.label, systemImage: "tag").font(.subheadline.weight(.medium)).foregroundStyle(MessagingTheme.accent)
                        }
                        if record.type == 0 {
                            Text(record.summary).font(.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Button { preview(record) } label: {
                                HStack(spacing: 12.zoom()) {
                                    Image(systemName: record.type == 1 ? "photo" : record.type == 2 ? "play.rectangle" : "doc")
                                        .font(.title2).frame(width: 44, height: 44).accessibilityHidden(true)
                                    Text(record.summary).font(.body).multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
                                }.frame(minHeight: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(![1, 2, 5].contains(record.type))
                        }
                        Label(record.statusText, systemImage: record.status == 1 ? "clock" : record.errors > 0 || record.status == 3 ? "exclamationmark.circle" : record.status == 2 ? "checkmark.circle" : "questionmark.circle")
                            .font(.subheadline).foregroundStyle(record.errors > 0 || record.status == 3 ? MessagingTheme.error : MessagingTheme.secondaryText)
                    }.padding(.vertical, 8.zoom())
                    NavigationLink { MassMessageRecipientsView(context: store.context, record: record, failures: false) } label: {
                        Label("全部接收对象 · \(record.total)", systemImage: "person.2").font(.subheadline).frame(minHeight: 44)
                    }
                    if record.errors > 0 {
                        NavigationLink { MassMessageRecipientsView(context: store.context, record: record, failures: true) } label: {
                            Label("发送失败 · \(record.errors)", systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(MessagingTheme.error).frame(minHeight: 44)
                        }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack { resend(record); Spacer(); delete(record) }
                        VStack(alignment: .leading) { resend(record); delete(record) }
                    }
                } header: {
                    Text(MassMessagePresentation.time(record.sentAt)).textCase(nil)
                }.listRowBackground(MessagingTheme.surface)
            }
            if !store.records.isEmpty && store.hasMore {
                Button(store.loading ? "正在加载" : "加载更多记录") { Task { await store.loadMore() } }
                    .frame(maxWidth: .infinity, minHeight: 44).disabled(store.loading)
            }
        }
        .listStyle(.insetGrouped)
        .frame(maxWidth: 720).frame(maxWidth: .infinity)
        .refreshable { await store.reload() }
        .task { if !didLoad { didLoad = true; await store.reload() } }
        .toolbar { ToolbarItem(placement: .primaryAction) { Button { draft = MassMessageDraftRequest(original: nil) } label: { Label("新建群发", systemImage: "square.and.pencil") }.frame(minWidth: 44, minHeight: 44).disabled(!allowed) } }
        .messagingLoadingToast(store.loading && store.records.isEmpty)
        .messagingFeedbackToast(store.errorMessage ?? store.feedback, isEnabled: draft == nil)
        .sheet(item: $draft, onDismiss: {
            if sent { sent = false; store.feedback = "群发已受理，可刷新查看发送结果"; Task { await store.reload() } }
        }) { request in
            NavigationStack { MassMessageComposerView(context: store.context, original: request.original) { sent = true } }
        }
        .confirmationDialog("删除这条群发记录？", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            if let record = pendingDelete { Button("删除记录", role: .destructive) { pendingDelete = nil; Task { _ = await store.delete(record) } } }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: { Text("仅删除群发记录，已发送的消息不会撤回。") }
        .chatPhotoBrowser(item: $gallery, context: store.context, includeCachedHistory: false)
        .sheet(item: $file) { message in NavigationStack {
            ChatMediaDetailView(message: message, context: store.context, onVoicePlayed: {})
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { file = nil }.frame(minHeight: 44) } }
        } }
    }

    private func resend(_ record: MassMessageRecord) -> some View {
        Button("再发一次") { draft = MassMessageDraftRequest(original: record) }
            .buttonStyle(.borderless).frame(minHeight: 44).disabled(!allowed || ![0, 1, 2, 5].contains(record.type) || store.deleting.contains(record.id))
    }
    private func delete(_ record: MassMessageRecord) -> some View {
        Button(role: .destructive) { pendingDelete = record } label: { Label(store.deleting.contains(record.id) ? "正在删除" : "删除", systemImage: "trash") }
            .buttonStyle(.borderless).frame(minHeight: 44).disabled(store.deleting.contains(record.id))
    }
    private func preview(_ record: MassMessageRecord) {
        let message = MassMessagePresentation.message(record, context: store.context)
        if record.type == 5 { file = message }
        else { gallery = ChatPhotoBrowserRequest(selected: message, messages: [message]) }
    }
}
