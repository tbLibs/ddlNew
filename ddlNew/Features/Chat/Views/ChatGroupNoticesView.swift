//
//  ChatGroupNoticesView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

struct ChatGroupNoticesView: View {
    let route: ChatRoute
    @StateObject private var store = ChatNoticesStore(client: SDKChatNoticesClient())
    @State private var openedContext: ChatContext?
    @State private var editorPresentation: ChatNoticeEditorPresentation?
    @State private var confirmDelete: ChatGroupNotice?
    @State private var role = 0
    @State private var deletedID: String?
    @State private var feedback: String?
    @State private var pendingEditorFeedback: String?

    var body: some View {
        List {
            if store.errorMessage != nil {
                Button("重新加载公告") { Task { await store.reload() } }.frame(minHeight: 44).disabled(store.busy)
                    .listRowBackground(MessagingTheme.surface)
            }
            if store.notices.isEmpty && !store.busy {
                VStack(spacing: 12.zoom()) { Image(systemName: "text.bubble").font(.largeTitle).accessibilityHidden(true); Text("暂无群公告").font(.subheadline) }.foregroundStyle(MessagingTheme.secondaryText).frame(maxWidth: .infinity, minHeight: 180.zoom()).listRowBackground(MessagingTheme.background).listRowSeparator(.hidden)
            }
            ForEach(store.notices) { notice in
                NavigationLink {
                    ChatNoticeDetailView(store: store, notice: notice, canManage: [1, 2].contains(role), deletedID: deletedID, onEdit: { edit($0) }, onDelete: { deleteNotice($0) })
                } label: {
                    VStack(alignment: .leading, spacing: 8.zoom()) {
                        if notice.pinned { Label("置顶公告", systemImage: "pin.fill").font(.caption).foregroundStyle(MessagingTheme.accent) }
                        Text(notice.content).font(.body).foregroundStyle(MessagingTheme.text).lineLimit(3)
                        Text([notice.author, notice.timestamp].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                    }.padding(.vertical, 12.zoom())
                }.listRowBackground(MessagingTheme.surface)
                    .contextMenu { if [1, 2].contains(role) { Button("编辑公告") { edit(notice) }; Button("删除公告", role: .destructive) { confirmDelete = notice } } }
            }
            if store.hasMore && !store.busy { Button("加载更多") { Task { await store.loadMore() } }.frame(maxWidth: .infinity, minHeight: 44).listRowBackground(MessagingTheme.surface) }
        }.listStyle(.plain).navigationTitle("群公告").modifier(MessagingPageChrome())
            .messagingLoadingToast(store.busy && editorPresentation == nil)
            .messagingFeedbackToast(feedback, isEnabled: editorPresentation == nil)
            .onChange(of: store.errorMessage) { if editorPresentation == nil { feedback = $0 } }
            .refreshable { await store.reload() }
            .toolbar { if [1, 2].contains(role) { Button("发布") { edit(nil) }.frame(minHeight: 44).disabled(store.busy) } }
            .task {
                guard let context = ChatRuntime.shared.context(for: route) else { return }
                let client = SDKChatSettingsClient()
                role = (try? await client.load(context: context).group?.role) ?? 0; client.close()
                guard ChatRuntime.shared.isCurrent(context) else { return }
                registerCleanup()
                // 子页或编辑弹窗返回时保留列表与详情，避免清空列表导致导航退回根页。
                if openedContext != context || (store.notices.isEmpty && store.hasMore && !store.busy) {
                    openedContext = context
                    await store.open(context)
                }
            }
            .sheet(item: $editorPresentation, onDismiss: {
                if let message = pendingEditorFeedback { feedback = message; pendingEditorFeedback = nil }
            }) { presentation in
                ChatNoticeEditorView(store: store, notice: presentation.notice) {
                    pendingEditorFeedback = store.errorMessage ?? "公告已保存"
                }
            }
            .confirmationDialog("删除群公告", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }), titleVisibility: .visible) {
                if let notice = confirmDelete {
                    Button("删除公告", role: .destructive) {
                        deleteNotice(notice)
                        confirmDelete = nil
                    }
                }
            } message: { Text("删除后所有成员将无法查看此公告。") }
    }

    /// 弹窗携带正在显示的公告快照，避免布尔sheet首次捕获旧正文或创建模式。
    private func edit(_ notice: ChatGroupNotice?) { feedback = nil; editorPresentation = ChatNoticeEditorPresentation(notice: notice) }

    /// 当前页面确认后才提交，列表与详情共用删除回执和返回处理，不触发父页弹框。
    private func deleteNotice(_ notice: ChatGroupNotice) {
        Task {
            feedback = nil
            if await store.save(notice, content: notice.content, pinned: notice.pinned, deleting: true) {
                deletedID = notice.id
                if store.errorMessage == nil { feedback = "公告已删除" }
            }
        }
    }

    /// 公告页退出身份时停止SDK等待，不强持有整个视图。
    private func registerCleanup() { let notices = store; ChatRuntime.shared.registerCleanup(owner: notices, conversationID: route.id) { [weak notices] in notices?.close() } }
}

/// 旧版详情在正文下方提供编辑和删除，普通成员只读。
private struct ChatNoticeDetailView: View {
    @ObservedObject var store: ChatNoticesStore
    let notice: ChatGroupNotice
    let canManage: Bool
    let deletedID: String?
    let onEdit: (ChatGroupNotice) -> Void
    let onDelete: (ChatGroupNotice) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete: ChatGroupNotice?
    private var current: ChatGroupNotice {
        if let updated = store.notices.first(where: { $0.id == notice.id }), updated != notice { return updated }
        return store.detail?.id == notice.id ? store.detail ?? notice : notice
    }

    var body: some View {
        MessagingScroll {
            VStack(alignment: .leading, spacing: 16.zoom()) {
                MessagingCard {
                    VStack(alignment: .leading, spacing: 16.zoom()) {
                        if current.pinned { Label("置顶公告", systemImage: "pin.fill").font(.caption).foregroundStyle(MessagingTheme.accent) }
                        Text([current.author, current.timestamp].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                        Text(current.content).font(.body).foregroundStyle(MessagingTheme.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if canManage {
                    Button("编辑公告") { onEdit(current) }.buttonStyle(MessagingActionButtonStyle(fullWidth: true)).disabled(store.busy)
                    Button("删除公告", role: .destructive) { confirmDelete = current }.buttonStyle(MessagingActionButtonStyle(fill: MessagingTheme.surface, foreground: MessagingTheme.error, border: MessagingTheme.error, fullWidth: true)).disabled(store.busy)
                }
            }.padding(16.zoom())
        }.navigationTitle("群公告").modifier(MessagingPageChrome())
        .messagingLoadingToast(store.busy, title: "正在更新")
        .messagingFeedbackToast(store.errorMessage)
        // 确认框由正在显示的详情页持有，避免挂在隐藏列表上等返回后才弹出。
        .confirmationDialog("删除群公告", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }), titleVisibility: .visible) {
            if let notice = confirmDelete {
                Button("删除公告", role: .destructive) { onDelete(notice); confirmDelete = nil }.disabled(store.busy)
            }
        } message: { Text("删除后所有成员将无法查看此公告。") }
        .onDisappear { confirmDelete = nil }
            .task { await store.read(notice) }
            .onChange(of: deletedID) { if $0 == notice.id { dismiss() } }
    }
}

/// 每次编辑使用独立呈现身份，发布和编辑不会共用旧sheet捕获值。
private struct ChatNoticeEditorPresentation: Identifiable {
    let id = UUID()
    let notice: ChatGroupNotice?
}

/// 公告表单拥有自己的草稿，稳定公告ID、正文和置顶状态同时进入弹窗。
private struct ChatNoticeEditorView: View {
    @ObservedObject var store: ChatNoticesStore
    let notice: ChatGroupNotice?
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var input: String
    @State private var pinned: Bool
    @State private var sendMessage = false
    @State private var confirmDiscard = false
    @FocusState private var editorFocused: Bool

    /// 初始快照只在新呈现时使用，后续刷新不覆盖正在编辑的草稿。
    init(store: ChatNoticesStore, notice: ChatGroupNotice?, onSaved: @escaping () -> Void) {
        self.store = store; self.notice = notice; self.onSaved = onSaved
        _input = State(initialValue: notice?.content ?? "")
        _pinned = State(initialValue: notice?.pinned ?? false)
    }

    private var isDirty: Bool { input != (notice?.content ?? "") || pinned != (notice?.pinned ?? false) || sendMessage }

    var body: some View {
        NavigationStack {
            MessagingScroll {
                VStack(alignment: .leading, spacing: 12.zoom()) {
                    Text("公告正文").font(.footnote).foregroundStyle(MessagingTheme.secondaryText)
                    MessagingCard {
                        ZStack(alignment: .topLeading) {
                            if input.isEmpty { Text("请输入群公告内容").foregroundStyle(MessagingTheme.secondaryText).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false) }
                            TextEditor(text: $input).focused($editorFocused).scrollContentBackground(.hidden).frame(minHeight: 220.zoom()).accessibilityLabel("公告正文")
                        }
                    }
                    MessagingCard {
                        VStack(spacing: 16.zoom()) { Toggle("置顶公告", isOn: $pinned); Toggle("作为群消息发送", isOn: $sendMessage) }
                    }
                }.padding(16.zoom())
            }
            .navigationTitle(notice == nil ? "发布公告" : "编辑公告").modifier(MessagingPageChrome())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { if isDirty { confirmDiscard = true } else { dismiss() } }.disabled(store.busy) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { if await store.save(notice, content: input, pinned: pinned, sendMessage: sendMessage) { onSaved(); dismiss() } } }
                        .buttonStyle(.plain).frame(minHeight: 44).disabled(store.busy || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .messagingLoadingToast(store.busy, title: "正在保存")
        .messagingFeedbackToast(store.errorMessage)
        .interactiveDismissDisabled(store.busy || isDirty)
        .confirmationDialog("放弃公告修改？", isPresented: $confirmDiscard, titleVisibility: .visible) { Button("放弃修改", role: .destructive) { dismiss() } }
    }
}
