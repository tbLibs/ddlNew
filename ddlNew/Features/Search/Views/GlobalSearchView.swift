// Created by taobo on 2026/10/13.
import SwiftUI

/// 本地好友、群和消息缓存的分类搜索，消息结果按稳定 ID 回到原会话。
struct GlobalSearchView: View {
    @ObservedObject private var store = LoginSessionService.shared.globalSearch
    @ObservedObject private var session = UserSessionStore.shared
    @ObservedObject private var roles = UserRoleAuthorityStore.shared
    @State private var query = ""
    @State private var expanded: Set<GlobalSearchKind> = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("搜索本机已同步的好友、群聊和聊天内容")
                    .font(.subheadline).foregroundStyle(.secondary)
                if store.isSearching { ProgressView("正在搜索") }
                if let error = store.errorMessage {
                    Text(error).foregroundStyle(ClubTheme.error)
                    Button("重试") { Task { await store.search(query) } }.frame(minHeight: 44)
                }
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !store.isSearching, store.results.isEmpty, store.errorMessage == nil {
                    Text("没有找到相关结果").frame(maxWidth: .infinity).padding(.vertical, 40)
                        .accessibilityIdentifier("globalSearchEmpty")
                }
                ForEach(GlobalSearchKind.allCases) { kind in
                    resultSection(kind)
                }
            }.padding(20)
        }
        .background(HomeTheme.background)
        .navigationTitle("全局搜索").navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .searchable(text: $query, prompt: "搜索好友、群聊或消息")
        .task {
            await store.search(query)
        }
        .task(id: query) {
            do { try await Task<Never, Never>.sleep(nanoseconds: 250_000_000) }
            catch { return }
            expanded = []
            await store.search(query)
        }
        .onChange(of: roles.current?.allows("isShowFileAssistant")) { _ in Task { await store.search(query) } }
        .onDisappear { store.clearQuery() }
    }

    /// 每类先展示三条，展开保留完整 SDK 查询结果。
    @ViewBuilder private func resultSection(_ kind: GlobalSearchKind) -> some View {
        let records = store.results.filter { $0.kind == kind }
        if !records.isEmpty {
            Text(kind.rawValue).font(.headline).accessibilityAddTraits(.isHeader)
            ForEach(expanded.contains(kind) ? records : Array(records.prefix(3))) { result in
                resultLink(result)
            }
            if records.count > 3 && !expanded.contains(kind) {
                Button("查看全部\(kind.rawValue)（\(records.count)）") { expanded.insert(kind) }
                    .frame(minHeight: 44)
            }
        }
    }

    /// 普通好友打开最新资料，助手与群及消息打开真实聊天路由。
    @ViewBuilder private func resultLink(_ result: GlobalSearchResult) -> some View {
        if result.kind == .friend && result.peerID != "100002" {
            NavigationLink(value: ContactsRoute(contactID: result.peerID)) { resultLabel(result) }
        } else {
            NavigationLink(value: ChatRoute(id: result.peerID,
                kind: result.kind == .group || result.kind == .groupMessage ? .group : .single,
                title: result.title, avatarURL: result.avatar, targetMessageID: result.messageID)) {
                resultLabel(result)
            }
        }
    }

    /// 使用动态字号显示摘要和日期，长消息不撑破窄屏。
    private func resultLabel(_ result: GlobalSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.title).font(.body.weight(.semibold)).foregroundStyle(HomeTheme.text)
            if !result.detail.isEmpty { Text(result.detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(3) }
            if let date = result.date { Text(date, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(HomeTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("globalSearch.\(result.id)")
    }
}
