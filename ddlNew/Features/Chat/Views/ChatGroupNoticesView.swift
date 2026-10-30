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
    @State private var selectedNotice: ChatGroupNotice?
    @State private var selectionRevision = UUID()
    @State private var closeDetailAfterEditor = false
    @State private var feedback: String?
    @State private var pendingEditorFeedback: String?
    @State private var editRevision = UUID()

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
                Button { selectionRevision = UUID(); selectedNotice = notice } label: {
                    VStack(alignment: .leading, spacing: 8.zoom()) {
                        if notice.pinned { Label("置顶公告", systemImage: "pin.fill").font(.caption).foregroundStyle(MessagingTheme.accent) }
                        Text(notice.content).font(.body).foregroundStyle(MessagingTheme.text).lineLimit(3)
                        Text([notice.author, notice.displayTimestamp()].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                    }.padding(.vertical, 12.zoom())
                }.listRowBackground(MessagingTheme.surface)
                    .contextMenu { if [1, 2].contains(store.managementRole) { Button("编辑公告") { edit(notice) }; Button("删除公告", role: .destructive) { confirmDelete = notice } } }
            }
            if store.hasMore && !store.busy { Button("加载更多") { Task { await store.loadMore() } }.frame(maxWidth: .infinity, minHeight: 44).listRowBackground(MessagingTheme.surface) }
        }.listStyle(.plain).navigationTitle("群公告").modifier(MessagingPageChrome())
            .messagingLoadingToast(store.busy && editorPresentation == nil)
            .messagingFeedbackToast(feedback, isEnabled: editorPresentation == nil)
            .onChange(of: store.errorMessage) { if editorPresentation == nil { feedback = $0 } }
            // 详情路由独立于公告行；删行或刷新排序不会销毁正在显示的导航目标。
            .navigationDestination(isPresented: Binding(get: { selectedNotice != nil }, set: { if !$0 { selectedNotice = nil; selectionRevision = UUID() } })) {
                if let notice = selectedNotice {
                    ChatNoticeDetailView(store: store, notice: notice, canManage: [1, 2].contains(store.managementRole), onEdit: { edit($0) }, onDelete: { deleteNotice($0, onAccepted: $1) })
                }
            }
            .refreshable { await store.reload() }
            .onDisappear { if selectedNotice == nil && editorPresentation == nil { editRevision = UUID() } }
            .toolbar { if [1, 2].contains(store.managementRole) { Button("发布") { edit(nil) }.frame(minHeight: 44).disabled(store.busy) } }
            .task {
                guard let context = ChatRuntime.shared.context(for: route) else { return }
                guard ChatRuntime.shared.isCurrent(context) else { return }
                registerCleanup()
                // 子页或编辑弹窗返回时保留列表与详情，避免清空列表导致导航退回根页。
                if openedContext != context || (store.notices.isEmpty && store.hasMore && !store.busy) {
                    openedContext = context
                    await store.open(context)
                } else { await store.refreshRole() }
            }
            .sheet(item: $editorPresentation, onDismiss: {
                if closeDetailAfterEditor { selectedNotice = nil; selectionRevision = UUID(); closeDetailAfterEditor = false }
                if let message = pendingEditorFeedback { feedback = message; pendingEditorFeedback = nil }
            }) { presentation in
                ChatNoticeEditorView(store: store, notice: presentation.notice, onDelete: { deleteNotice($0, onAccepted: $1) }) {
                    // xgd编辑成功直接回公告列表，重读后的公告身份不能继续沿用旧详情。
                    closeDetailAfterEditor = presentation.notice != nil && selectedNotice?.id == presentation.notice?.id
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

    /// 发布直接开稿，既有公告必须先读取完整正文，摘要或失败结果不能进入编辑器。
    private func edit(_ notice: ChatGroupNotice?) {
        feedback = nil
        guard let notice else { editorPresentation = ChatNoticeEditorPresentation(notice: nil); return }
        let revision = UUID(); editRevision = revision
        let selection = selectionRevision
        let selectedID = selectedNotice?.id
        guard let context = ChatRuntime.shared.context(for: route) else { return }
        Task {
            guard let full = await store.prepareEdit(notice), editRevision == revision,
                  selectionRevision == selection, selectedNotice?.id == selectedID, ChatRuntime.shared.isCurrent(context) else { return }
            editorPresentation = ChatNoticeEditorPresentation(notice: full)
        }
    }

    /// 当前页面确认后才提交，列表与详情共用删除回执和返回处理，不触发父页弹框。
    private func deleteNotice(_ notice: ChatGroupNotice, onAccepted: @escaping () -> Void = {}) {
        let selection = selectionRevision
        let selectedID = selectedNotice?.id
        let editorID = editorPresentation?.id
        guard let context = ChatRuntime.shared.context(for: route) else { return }
        Task {
            feedback = nil
            if await store.save(notice, content: notice.content, pinned: notice.pinned, deleting: true, onAccepted: {
                guard selectionRevision == selection, selectedNotice?.id == selectedID,
                      editorPresentation?.id == editorID, ChatRuntime.shared.isCurrent(context) else { return }
                feedback = "公告已删除"
                // 可见编辑页主动dismiss后，sheet onDismiss再关闭下层详情，避免停留已删除正文。
                closeDetailAfterEditor = editorPresentation?.notice?.id == notice.id && selectedNotice?.id == notice.id
                onAccepted()
            }) {
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
    let onEdit: (ChatGroupNotice) -> Void
    let onDelete: (ChatGroupNotice, @escaping () -> Void) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete: ChatGroupNotice?
    private var current: ChatGroupNotice {
        return store.detail?.id == notice.id ? store.detail ?? notice : notice
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16.zoom()) {
                Group {
                    VStack(alignment: .leading, spacing: 16.zoom()) {
                        if current.pinned { Label("置顶公告", systemImage: "pin.fill").font(.caption).foregroundStyle(MessagingTheme.accent) }
                        Text([current.author, current.displayTimestamp()].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                        Text(current.content).font(.body).foregroundStyle(MessagingTheme.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

            }.padding(20.zoom())
        }.background(MessagingTheme.surface.ignoresSafeArea()).navigationTitle("群公告").modifier(MessagingPageChrome())
        .safeAreaInset(edge: .bottom) {
            if canManage {
                VStack(spacing: 12.zoom()) {
                    Button("编辑公告") { onEdit(current) }.buttonStyle(MessagingActionButtonStyle(fullWidth: true)).disabled(store.busy)
                    Button("删除公告", role: .destructive) { confirmDelete = current }.buttonStyle(MessagingActionButtonStyle(fill: MessagingTheme.surface, foreground: MessagingTheme.error, border: MessagingTheme.error, fullWidth: true)).disabled(store.busy)
                }.frame(maxWidth: 640).padding(20.zoom()).frame(maxWidth: .infinity).background(MessagingTheme.surface)
            }
        }
        .messagingLoadingToast(store.busy, title: "正在更新")
        .messagingFeedbackToast(store.errorMessage)
        // 确认框由正在显示的详情页持有，避免挂在隐藏列表上等返回后才弹出。
        .confirmationDialog("删除群公告", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }), titleVisibility: .visible) {
            if let notice = confirmDelete {
                Button("删除公告", role: .destructive) { onDelete(notice) { dismiss() }; confirmDelete = nil }.disabled(store.busy)
            }
        } message: { Text("删除后所有成员将无法查看此公告。") }
        .onDisappear { confirmDelete = nil }
            .task { await store.read(notice) }
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
    let onDelete: (ChatGroupNotice, @escaping () -> Void) -> Void
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var input: String
    @State private var pinned: Bool
    @State private var sendMessage = false
    @State private var confirmDiscard = false
    @State private var confirmDelete = false
    @FocusState private var editorFocused: Bool

    /// 初始快照只在新呈现时使用，后续刷新不覆盖正在编辑的草稿。
    init(store: ChatNoticesStore, notice: ChatGroupNotice?, onDelete: @escaping (ChatGroupNotice, @escaping () -> Void) -> Void, onSaved: @escaping () -> Void) {
        self.store = store; self.notice = notice; self.onDelete = onDelete; self.onSaved = onSaved
        _input = State(initialValue: notice?.content ?? "")
        _pinned = State(initialValue: notice?.pinned ?? false)
    }

    private var isDirty: Bool { input != (notice?.content ?? "") || pinned != (notice?.pinned ?? false) || sendMessage }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12.zoom()) {
                    Text("正文").font(.footnote.weight(.medium)).foregroundStyle(MessagingTheme.secondaryText)
                    ZStack(alignment: .topLeading) {
                            if input.isEmpty { Text("请输入群公告内容").foregroundStyle(MessagingTheme.secondaryText).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false) }
                            TextEditor(text: $input).focused($editorFocused).scrollContentBackground(.hidden).frame(minHeight: 272.zoom()).accessibilityLabel("公告正文")
                        }.padding(12.zoom()).background(MessagingTheme.background, in: RoundedRectangle(cornerRadius: 12.zoom()))
                    VStack(spacing: 0) {
                        Toggle("置顶公告", isOn: $pinned).padding(.vertical, 14.zoom())
                        Divider().overlay(MessagingTheme.divider)
                        Toggle("作为群消息发送", isOn: $sendMessage).padding(.vertical, 14.zoom())
                    }
                    if notice != nil {
                        Button("删除公告", role: .destructive) { confirmDelete = true }
                            .buttonStyle(MessagingActionButtonStyle(fill: MessagingTheme.surface, foreground: MessagingTheme.error, border: MessagingTheme.error, fullWidth: true)).disabled(store.busy)
                    }
                }.padding(20.zoom())
            }.background(MessagingTheme.surface.ignoresSafeArea()).scrollDismissesKeyboard(.interactively)
            .navigationTitle(notice == nil ? "发布公告" : "编辑公告").modifier(MessagingPageChrome())
            .safeAreaInset(edge: .bottom) {
                Button(notice == nil ? "发布" : "保存") { Task { if await store.save(notice, content: input, pinned: pinned, sendMessage: sendMessage) { onSaved(); dismiss() } } }
                    .buttonStyle(MessagingActionButtonStyle(fullWidth: true)).disabled(store.busy || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .frame(maxWidth: 640).padding(20.zoom()).frame(maxWidth: .infinity).background(MessagingTheme.surface)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { if isDirty { confirmDiscard = true } else { dismiss() } }.disabled(store.busy) }

            }
        }
        .messagingLoadingToast(store.busy, title: "正在保存")
        .messagingFeedbackToast(store.errorMessage)
        .interactiveDismissDisabled(store.busy || isDirty)
        .alert("删除群公告", isPresented: $confirmDelete) {
            if let notice { Button("删除公告", role: .destructive) { onDelete(notice) { dismiss() } }.disabled(store.busy) }
            Button("取消", role: .cancel) {}
        } message: { Text("删除后所有成员将无法查看此公告。") }
        .confirmationDialog("放弃公告修改？", isPresented: $confirmDiscard, titleVisibility: .visible) { Button("放弃修改", role: .destructive) { dismiss() } }
    }
}
