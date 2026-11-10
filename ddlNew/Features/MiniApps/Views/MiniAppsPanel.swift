//
//  MiniAppsPanel.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//
import SwiftUI

/// 消息页的折叠应用区域，管理和打开共用真实记录，不影响会话筛选或滚动所有权。
struct MiniAppsPanel: View {
    @Environment(\.locale) private var localizationLocale
    @ObservedObject var store: MiniAppsStore
    @ObservedObject var feature: MiniAppsFeature
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var expanded: Bool
    @State private var managing = false
    @State private var editor: EditorRequest?
    @State private var passwordRecord: MiniAppRecord?
    @State private var pendingEditor: EditorRequest?
    @State private var pendingOpen: MiniAppRecord?
    @State private var deleting: MiniAppRecord?
    @State private var opening = false
    @State private var error: String?
    @State private var openTask: Task<Void, Never>?
    private struct EditorRequest: Identifiable {
        let id = UUID()
        let record: MiniAppRecord?
        let password: String
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Button { Task { await store.refresh() } } label: { Label(L10n.tr("刷新"), systemImage: "arrow.clockwise").font(.subheadline).frame(minHeight: 44) }
                Spacer()
                Button(managing ? L10n.tr("完成") : L10n.tr("管理")) {
                    deleting = nil
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { managing.toggle() }
                }.font(.subheadline.weight(.medium)).frame(minHeight: 44)
                    .disabled(store.items.isEmpty)
            }.disabled(store.isLoading || store.isBusy || opening)
            if store.isLoading && store.items.isEmpty {
                ProgressView(L10n.tr("正在加载应用")).frame(maxWidth: .infinity, minHeight: 88)
            } else {
                if store.items.isEmpty && store.hasLoaded {
                    Text(L10n.tr("添加常用应用，下次从这里直接打开。"))
                        .font(.callout).foregroundStyle(MessagingTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
                }
                MiniAppsGrid(items: store.items, managing: managing,
                             select: select, delete: { deleting = $0 }, add: { editor = EditorRequest(record: nil, password: "") })
                    .disabled(store.isBusy || opening)
                if store.hasMore && store.hasLoaded {
                    Button { Task { await store.loadMore() } } label: {
                        HStack { if store.isLoading { ProgressView() }; Text(store.isLoading ? L10n.tr("正在加载") : L10n.tr("加载更多应用")) }.frame(maxWidth: .infinity, minHeight: 44)
                    }.disabled(store.isLoading || store.isBusy)
                }
            }
            if let message = error ?? store.feedback {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message).font(.callout).foregroundStyle(MessagingTheme.error).fixedSize(horizontal: false, vertical: true)
                    Button(L10n.tr("重试")) { error = nil; Task { await store.refresh() } }.frame(minHeight: 44).disabled(store.isBusy || store.isLoading)
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4).tint(MessagingTheme.accent)
        // 同一List行内有多个操作，禁止automatic样式把点击分派到整行按钮。
        .buttonStyle(MiniAppButtonStyle())
        .sheet(item: $editor) { request in
            MiniAppEditorView(store: store, record: request.record, password: request.password) {
                if let id = request.record?.id { feature.invalidate(id: id) }
            }
        }
        .sheet(item: $passwordRecord, onDismiss: passwordDismissed) { record in
            MiniAppPasswordView(store: store, record: record) { unlocked, password in
                if managing { pendingEditor = EditorRequest(record: unlocked, password: password) }
                else { pendingOpen = unlocked }
                passwordRecord = nil
            }
        }
        .alert(L10n.tr("删除应用？"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { record in
            Button(L10n.tr("取消"), role: .cancel) { deleting = nil }
            Button(L10n.tr("删除"), role: .destructive) {
                deleting = nil
                Task { if await store.delete(record) { feature.removeFloat(id: record.id); feature.invalidate(id: record.id) } }
            }
        } message: { record in Text(L10n.tr("将从我的应用移除“\(record.name)”。")) }
        .onDisappear { openTask?.cancel() }
    }
    private func select(_ record: MiniAppRecord) {
        guard !opening, !store.isBusy else { return }
        if managing && !record.canEdit { return }
        error = nil
        if record.passwordEnabled { passwordRecord = record; return }
        if managing { editor = EditorRequest(record: record, password: ""); return }
        opening = true
        openTask = Task { @MainActor in
            defer { opening = false }
            do {
                let current = try await store.detail(id: record.id)
                guard !Task.isCancelled else { return }
                if current.passwordEnabled { passwordRecord = current }
                else { expanded = false; feature.open(current) }
            } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }
    private func passwordDismissed() {
        if let request = pendingEditor { pendingEditor = nil; editor = request }
        if let record = pendingOpen { pendingOpen = nil; expanded = false; feature.open(record) }
    }
}
