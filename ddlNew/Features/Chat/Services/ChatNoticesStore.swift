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
    private let client: any ChatNoticesClient
    private var generation = UUID()
    private var detailRevision = UUID()
    private var page = 1

    /// 生产注入SDK客户端，离线仅替换传输层，不复制Store逻辑。
    init(client: any ChatNoticesClient) { self.client = client }

    /// 页加载使用当前runtime认证身份，旧页数据在再次打开时清理。
    func open(_ context: ChatContext) async { close(); client.open(context); await loadMore() }
    /// 分页失败保留已有公告和原页号，重试不跳过20条。
    func loadMore() async {
        guard !busy, hasMore else { return }
        let run = generation; busy = true; errorMessage = nil
        defer { if generation == run { busy = false } }
        do {
            let rows = try await client.load(page: page)
            guard generation == run else { return }
            apply(rows, replacing: false); page += 1
        } catch { if generation == run { errorMessage = error.localizedDescription } }
    }
    /// 下拉或失败重试重新读首屏，读取失败保留当前名单与分页位置。
    func reload() async {
        guard !busy else { return }
        let run = generation; busy = true; errorMessage = nil
        defer { if generation == run { busy = false } }
        do {
            let rows = try await client.load(page: 1)
            guard generation == run else { return }
            apply(rows, replacing: true); page = 2
        } catch { if generation == run { errorMessage = error.localizedDescription } }
    }
    /// 保存成功后重新查询首屏，保存失败由界面保留原输入。
    func save(_ notice: ChatGroupNotice?, content: String, pinned: Bool, deleting: Bool = false, sendMessage: Bool = false) async -> Bool {
        guard !busy else { return false }
        let run = generation; busy = true; errorMessage = nil
        defer { if generation == run { busy = false } }
        do {
            try await client.save(notice, content: content, pinned: pinned, deleting: deleting, sendMessage: sendMessage)
            guard generation == run else { return false }
            detailRevision = UUID()
            if detail?.id == notice?.id { detail = nil }
            do {
                let rows = try await client.load(page: 1)
                guard generation == run else { return false }
                apply(rows, replacing: true); page = 2
            } catch {
                if generation == run { errorMessage = deleting ? "公告已删除，刷新列表失败，请下拉重试" : "公告已保存，刷新列表失败，请下拉重试" }
            }
            return generation == run
        } catch { if generation == run { errorMessage = error.localizedDescription }; return false }
    }
    /// 公告详情实际显示后已读，失败保正文可读。
    func read(_ notice: ChatGroupNotice) async {
        let run = generation; let revision = UUID(); detailRevision = revision; detail = nil; errorMessage = nil
        do {
            let current = try await client.detail(notice)
            guard generation == run, detailRevision == revision, !Task.isCancelled else { return }
            detail = current
            if let index = notices.firstIndex(where: { $0.id == current.id }) { notices[index] = current; sortNotices() }
            try await client.read(current)
        }
        catch { if generation == run, detailRevision == revision { errorMessage = error.localizedDescription } }
    }
    /// 首屏替换与分页合并只在完整读取成功后执行，不留下半页或空白占位。
    private func apply(_ rows: [ChatGroupNotice], replacing: Bool) {
        var map = replacing ? [:] : Dictionary(uniqueKeysWithValues: notices.map { ($0.id, $0) })
        for row in rows { map[row.id] = row }
        notices = Array(map.values); sortNotices(); hasMore = rows.count >= 20
    }
    /// 沿旧版按真实置顶分区，再按毫秒创建时间倒序，时间相同使用稳定ID。
    private func sortNotices() {
        notices.sort {
            if $0.pinned != $1.pinned { return $0.pinned }
            if $0.timestamp == $1.timestamp { return $0.id < $1.id }
            if let first = Int64($0.timestamp), let second = Int64($1.timestamp) { return first > second }
            return $0.timestamp > $1.timestamp
        }
    }
    /// 页面关闭取消所有公告等待和旧分页状态。
    func close() { generation = UUID(); detailRevision = UUID(); client.close(); notices = []; detail = nil; busy = false; hasMore = true; page = 1; errorMessage = nil }
}
