//
//  ChatNoticesStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import Combine

@MainActor final class ChatNoticesStore: ObservableObject {
    @Published private(set) var detail: ChatGroupNotice?
    @Published private(set) var notices: [ChatGroupNotice] = []
    @Published private(set) var busy = false
    @Published private(set) var hasMore = true
    @Published var errorMessage: String?
    private let client = SDKChatNoticesClient()
    private var generation = UUID()
    private var page = 1

    /// 页加载使用当前runtime认证身份，旧页数据在再次打开时清理。
    func open(_ context: ChatContext) async { close(); client.open(context); await loadMore() }
    /// 分页失败保留已有公告和原页号，重试不跳过20条。
    func loadMore() async {
        guard !busy, hasMore else { return }
        let run = generation; busy = true
        defer { if generation == run { busy = false } }
        do {
            let rows = try await client.load(page: page)
            guard generation == run else { return }
            var map = Dictionary(uniqueKeysWithValues: notices.map { ($0.id, $0) })
            for row in rows { map[row.id] = row }
            notices = map.values.sorted { $0.pinned != $1.pinned ? $0.pinned : $0.timestamp > $1.timestamp }
            hasMore = rows.count >= 20; page += 1
        } catch { if generation == run { errorMessage = error.localizedDescription } }
    }
    /// 保存成功后重新查询首屏，保存失败由界面保留原输入。
    func save(_ notice: ChatGroupNotice?, content: String, pinned: Bool, deleting: Bool = false, sendMessage: Bool = false) async -> Bool {
        guard !busy else { return false }
        let run = generation; busy = true
        do {
            try await client.save(notice, content: content, pinned: pinned, deleting: deleting, sendMessage: sendMessage)
            guard generation == run else { return false }
            busy = false; notices = []; page = 1; hasMore = true; await loadMore(); return true
        } catch { if generation == run { busy = false; errorMessage = error.localizedDescription }; return false }
    }
    /// 公告详情实际显示后已读，失败保正文可读。
    func read(_ notice: ChatGroupNotice) async {
        let run = generation; detail = nil
        do { let current = try await client.detail(notice); guard generation == run, !Task.isCancelled else { return }; detail = current; try await client.read(current) }
        catch { if generation == run { errorMessage = error.localizedDescription } }
    }
    /// 页面关闭取消所有公告等待和旧分页状态。
    func close() { generation = UUID(); client.close(); notices = []; detail = nil; busy = false; hasMore = true; page = 1; errorMessage = nil }
}
