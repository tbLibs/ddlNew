//
//  ChatHistorySearchView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

struct ChatHistorySearchView: View {
    let context: ChatContext
    let onLocate: (String) -> Void
    @StateObject private var store = ChatHistorySearchStore()
    @State private var category = ChatHistoryCategory.text
    @State private var keyword = ""
    @State private var memberID = ""
    @State private var members: [ChatGroupMember] = []
    @State private var memberError: String?
    @FocusState private var searchFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8.zoom()) {
                MessagingSearchField(placeholder: category == .files ? "搜索文件名" : "搜索聊天记录", text: $keyword, focus: $searchFocused, identifier: "chatHistorySearch")
                ScrollView(.horizontal, showsIndicators: false) { MessagingTabs(selection: $category) }
                if !members.isEmpty || memberError != nil {
                    HStack {
                        Text("发送成员").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                        Spacer()
                        Picker("发送成员", selection: $memberID) { Text("全部成员").tag(""); ForEach(members) { Text($0.name).tag($0.id) } }
                            .frame(minHeight: max(44, 44.zoom()))
                    }
                    if let memberError { HStack { Text(memberError).font(.caption).foregroundStyle(MessagingTheme.error); Button("重试") { Task { await loadMembers() } }.frame(minHeight: 44) } }
                }
            }.padding(.horizontal, 16.zoom()).padding(.top, 12.zoom()).background(MessagingTheme.surface)
            MessagingScroll {
                LazyVStack(spacing: 0) {
                    if let error = store.errorMessage {
                        VStack(spacing: 8.zoom()) { Text(error).foregroundStyle(MessagingTheme.error); Button("重试搜索") { Task { await search(reset: store.messages.isEmpty) } }.frame(minHeight: 44) }.padding(16.zoom())
                    }
                    ForEach(store.messages) { item in
                        Button { onLocate(item.serverID.isEmpty ? item.localID : item.serverID); dismiss() } label: { ChatSecondaryRecordRow(message: item) }
                            .buttonStyle(MessagingRowStyle()).accessibilityHint("返回聊天并定位此消息")
                        Divider().overlay(MessagingTheme.divider).padding(.leading, 72.zoom())
                    }
                    if store.busy { ProgressView("正在查找记录").padding(24.zoom()) }
                    if store.hasMore && !store.busy { Button("加载更多结果") { Task { await search(reset: false) } }.frame(minHeight: max(44, 44.zoom())) }
                    if store.messages.isEmpty && !store.busy && store.errorMessage == nil { Label("暂无匹配的聊天记录", systemImage: "magnifyingglass").foregroundStyle(MessagingTheme.secondaryText).padding(.vertical, 48.zoom()) }
                }
            }
        }
        .navigationTitle("查找聊天记录").modifier(MessagingPageChrome())
        .task { await loadMembers() }
        .task(id: keyword) { do { try await Task.sleep(nanoseconds: 250_000_000); await search(reset: true) } catch {} }
        .onChange(of: category) { _ in Task { await search(reset: true) } }
        .onChange(of: memberID) { _ in Task { await search(reset: true) } }
        .onDisappear { store.close() }
    }

    /// 成员筛选失败保留明确反馈，不能把失败解释成群内没有成员。
    private func loadMembers() async {
        guard context.route.kind == .group else { return }
        do { let values = try await SDKChatHistorySearchClient().members(context: context); guard !Task.isCancelled, ChatRuntime.shared.isCurrent(context) else { return }; members = values; memberError = nil }
        catch { guard !Task.isCancelled else { return }; memberError = "成员筛选暂不可用：" + error.localizedDescription }
    }
    /// 每次提交完整分类和成员范围，加载更多保留 SDK 偏移。
    private func search(reset: Bool) async { await store.search(context: context, category: category, keyword: keyword, memberID: memberID, reset: reset) }
}
