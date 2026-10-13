//
//  ChatHistorySearchView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

struct ChatHistorySearchView: View {
    let context: ChatContext
    let onLocate: (String) -> Void
    @StateObject private var store = ChatHistorySearchStore()
    @State private var category = ChatHistoryCategory.text
    @State private var keyword = ""
    @State private var memberID = ""
    @State private var members: [ChatGroupMember] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Picker("类型", selection: $category) { ForEach(ChatHistoryCategory.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                if !members.isEmpty { Picker("发送成员", selection: $memberID) { Text("所有成员").tag(""); ForEach(members) { Text($0.name).tag($0.id) } } }
                Text("搜索当前账号的本地聊天缓存，每次50条。") .font(.caption).foregroundStyle(.secondary)
            }
            if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
            ForEach(store.messages) { item in Button { onLocate(item.serverID.isEmpty ? item.localID : item.serverID); dismiss() } label: { VStack(alignment: .leading) { Text(item.displayText).lineLimit(3); Text(item.senderName).font(.caption).foregroundStyle(.secondary) } } }
            if store.hasMore { Button("加载更多结果") { Task { await search(reset: false) } }.disabled(store.busy) }
            if store.messages.isEmpty && !store.busy { Text("暂无匹配的聊天记录").foregroundStyle(.secondary) }
        }
        .searchable(text: $keyword, prompt: "文字或文件名")
        .navigationTitle("查找聊天记录")
        .task { members = (try? await SDKChatHistorySearchClient().members(context: context)) ?? []; await search(reset: true) }
        .task(id: keyword) { do { try await Task.sleep(nanoseconds: 250_000_000); await search(reset: true) } catch {} }
        .onChange(of: category) { _ in Task { await search(reset: true) } }
        .onChange(of: memberID) { _ in Task { await search(reset: true) } }
        .onDisappear { store.close() }
    }

    /// 每次提交传入完整分类和成员范围，加载更多保留生产SDK偏移。
    private func search(reset: Bool) async { await store.search(context: context, category: category, keyword: keyword, memberID: memberID, reset: reset) }
}
