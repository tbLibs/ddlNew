//
//  ChatHistorySearchStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import Combine

@MainActor final class ChatHistorySearchStore: ObservableObject {
    @Published private(set) var messages: [ChatMessageRecord] = []
    @Published private(set) var busy = false
    @Published private(set) var hasMore = false
    @Published var errorMessage: String?
    private var revision = UUID()
    private var offset = 0
    private let client = SDKChatHistorySearchClient()

    /// 搜索条件改变即清理旧分页身份，迟到结果不能覆盖新关键词。
    func search(context: ChatContext, category: ChatHistoryCategory, keyword: String, memberID: String, reset: Bool) async {
        if reset { revision = UUID(); messages = []; offset = 0; busy = false; hasMore = false; errorMessage = nil }
        guard !busy else { return }; let run = revision; busy = true
        defer { if revision == run { busy = false } }
        do {
            let page = try await client.search(context: context, category: category, keyword: keyword, memberIDs: memberID.isEmpty ? [] : [memberID], offset: offset)
            guard revision == run, !Task.isCancelled else { return }
            messages = ChatMessageMerge.merge(messages, with: page.messages).filter(\.isBody)
            offset = page.nextOffset; hasMore = page.hasMore; errorMessage = nil
        } catch { if revision == run { errorMessage = error.localizedDescription } }
    }
    /// 离页撤销搜索身份，下一页不复用旧词结果。
    func close() { revision = UUID(); messages = []; offset = 0; busy = false; hasMore = false; errorMessage = nil }
}
