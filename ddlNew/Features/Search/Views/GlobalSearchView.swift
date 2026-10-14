//
//  GlobalSearchView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

/// 本地好友、群和消息缓存的分类搜索，消息结果按稳定 ID 回到原会话。
struct GlobalSearchView: View {
    @ObservedObject private var store = LoginSessionService.shared.globalSearch
    @ObservedObject private var roles = UserRoleAuthorityStore.shared
    @State private var query = ""
    @State private var expanded: Set<GlobalSearchKind> = []
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            MessagingSearchField(placeholder: "搜索好友、群聊或消息", text: $query, focus: $searchFocused, identifier: "globalSearchInput")
                .padding(.horizontal, 16.zoom()).padding(.vertical, 12.zoom()).background(MessagingTheme.surface)
            MessagingScroll {
                LazyVStack(alignment: .leading, spacing: 12.zoom()) {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label("搜索已同步的好友、群聊和聊天记录", systemImage: "magnifyingglass").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText).frame(maxWidth: .infinity).padding(.vertical, 40.zoom())
                    }
                    if store.errorMessage != nil {
                        VStack(alignment: .leading, spacing: 8.zoom()) { Button("重试") { Task { await store.search(query) } }.frame(minHeight: max(44, 44.zoom())) }.padding(16.zoom())
                    }
                    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       !store.isSearching, store.results.isEmpty, store.errorMessage == nil {
                        Text("没有找到相关结果").foregroundStyle(MessagingTheme.secondaryText).frame(maxWidth: .infinity).padding(.vertical, 40.zoom()).accessibilityIdentifier("globalSearchEmpty")
                    }
                    ForEach(GlobalSearchKind.allCases) { kind in resultSection(kind) }
                }.padding(.vertical, 12.zoom())
            }
        }
        .navigationTitle("全局搜索").modifier(MessagingPageChrome())
        .messagingFeedbackToast(store.errorMessage)
        .messagingLoadingToast(store.isSearching, title: "正在搜索")
        .task { searchFocused = true }
        .task(id: query) {
            do { try await Task<Never, Never>.sleep(nanoseconds: 250_000_000) }
            catch { return }
            expanded = []
            await store.search(query)
        }
        .onChange(of: roles.current?.allows("isShowFileAssistant")) { _ in Task { await store.search(query) } }
        .onDisappear { store.clearQuery() }
    }

    /// 每类先展示三条，与旧版分类一致；展开保留完整 SDK 查询结果。
    @ViewBuilder private func resultSection(_ kind: GlobalSearchKind) -> some View {
        let records = store.results.filter { $0.kind == kind }
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack { Text(kind.rawValue).font(.headline); Spacer(); Text("\(records.count)").font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
                    .padding(16.zoom()).accessibilityAddTraits(.isHeader)
                ForEach(expanded.contains(kind) ? records : Array(records.prefix(3))) { result in
                    resultLink(result)
                    Divider().overlay(MessagingTheme.divider).padding(.leading, 72.zoom())
                }
                if records.count > 3 {
                    Button(expanded.contains(kind) ? "收起\(kind.rawValue)" : "查看更多\(kind.rawValue)") { if !expanded.insert(kind).inserted { expanded.remove(kind) }; searchFocused = false }
                        .font(.subheadline).frame(maxWidth: .infinity, minHeight: max(44, 48.zoom()))
                }
            }.background(MessagingTheme.surface)
        }
    }

    /// 普通好友打开最新资料，助手与群及消息打开真实聊天路由。
    @ViewBuilder private func resultLink(_ result: GlobalSearchResult) -> some View {
        if result.kind == .friend && result.peerID != "100002" {
            NavigationLink(value: ContactsRoute(contactID: result.peerID)) { resultLabel(result) }.buttonStyle(MessagingRowStyle())
        } else {
            NavigationLink(value: ChatRoute(id: result.peerID,
                kind: result.kind == .group || result.kind == .groupMessage ? .group : .single,
                title: result.title, avatarURL: result.avatar, targetMessageID: result.messageID)) {
                resultLabel(result)
            }.buttonStyle(MessagingRowStyle())
        }
    }

    /// 作者头像、摘要和日期沿用旧搜索行层级，长消息保持可读。
    private func resultLabel(_ result: GlobalSearchResult) -> some View {
        HStack(alignment: .top, spacing: 12.zoom()) {
            ChatSecondaryAvatar(name: result.title, resource: result.avatar, isGroup: result.kind == .group || result.kind == .groupMessage)
            VStack(alignment: .leading, spacing: 6.zoom()) {
                Text(result.title).font(.body.weight(.semibold)).foregroundStyle(MessagingTheme.text)
                if !result.detail.isEmpty { Text(result.detail).font(.subheadline).foregroundStyle(MessagingTheme.secondaryText).lineLimit(3) }
                if let date = result.date { Text(date, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(MessagingTheme.secondaryText).accessibilityHidden(true)
        }
        .padding(16.zoom()).frame(maxWidth: .infinity, minHeight: max(44, 44.zoom()), alignment: .leading).contentShape(Rectangle())
        .accessibilityIdentifier("globalSearch.\(result.id)")
    }
}
