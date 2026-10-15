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
    @Published private(set) var managementRole = 0
    @Published private(set) var deletedNoticeID: String?
    @Published var errorMessage: String?
    private let client: any ChatNoticesClient
    private var generation = UUID()
    private var detailRevision = UUID()
    private var roleRevision = UUID()
    private var page = 1
    private var deletedIDs: Set<String> = []

    /// 生产注入SDK客户端，离线仅替换传输层，不复制Store逻辑。
    init(client: any ChatNoticesClient) { self.client = client }

    /// 页加载使用当前runtime认证身份，旧页数据在再次打开时清理。
    func open(_ context: ChatContext) async {
        close(); client.open(context)
        async let role: Void = refreshRole()
        await loadMore()
        await role
    }
    /// 公告管理只查询群信息，成员分页或禁言名单失败不应隐藏管理入口。
    func refreshRole() async {
        let run = generation; let revision = UUID(); roleRevision = revision
        do {
            let role = try await client.managementRole()
            guard generation == run, roleRevision == revision else { return }
            managementRole = role
        } catch {
            guard generation == run, roleRevision == revision else { return }
            managementRole = 0
            if errorMessage == nil { errorMessage = error.localizedDescription }
        }
    }
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
        if generation == run { await refreshRole() }
    }
    /// 保存成功后重新查询首屏，保存失败由界面保留原输入。
    func save(_ notice: ChatGroupNotice?, content: String, pinned: Bool, deleting: Bool = false, sendMessage: Bool = false, onAccepted: (() -> Void)? = nil) async -> Bool {
        guard !busy else { return false }
        let run = generation; busy = true; errorMessage = nil
        defer { if generation == run { busy = false } }
        do {
            try await client.save(notice, content: content, pinned: pinned, deleting: deleting, sendMessage: sendMessage)
            guard generation == run else { return false }
            detailRevision = UUID()
            if deleting, let notice {
                // 删除受理即通知导航返回；列表回读慢或失败不能滞留在已删除正文。
                deletedIDs.insert(notice.id)
                notices.removeAll { $0.id == notice.id }
                deletedNoticeID = notice.id
                if detail?.id == notice.id { detail = nil }
            } else if let notice {
                // 首屏接口可以只有带省略号的摘要，不能覆盖已经确认保存的完整正文。
                var confirmed = detail?.id == notice.id ? detail ?? notice : notice
                confirmed.content = content; confirmed.pinned = pinned
                detail = confirmed
            }
            // 直接执行当前页面提供的返回动作，隐藏列表的onChange不会可靠触发。
            onAccepted?()
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
        _ = await loadDetail(notice, reportingRead: true)
    }

    /// 编辑必须先得到完整详情；失败时不把列表摘要当作可保存的原文。
    func prepareEdit(_ notice: ChatGroupNotice) async -> ChatGroupNotice? {
        guard !busy else { return nil }
        let run = generation; busy = true
        defer { if generation == run { busy = false } }
        return await loadDetail(notice, reportingRead: false)
    }

    /// 列表摘要与完整详情分开，保存、退出或另一详情读取会撤销旧正文的写入资格。
    private func loadDetail(_ notice: ChatGroupNotice, reportingRead: Bool) async -> ChatGroupNotice? {
        let run = generation; let revision = UUID(); detailRevision = revision
        if detail?.id != notice.id { detail = nil }
        errorMessage = nil
        do {
            let current = try await client.detail(notice)
            guard generation == run, detailRevision == revision, !Task.isCancelled else { return nil }
            detail = current
            if let index = notices.firstIndex(where: { $0.id == current.id }) { notices[index] = current; sortNotices() }
            if reportingRead { try await client.read(current) }
            guard generation == run, detailRevision == revision, !Task.isCancelled else { return nil }
            return current
        }
        catch { if generation == run, detailRevision == revision { errorMessage = error.localizedDescription }; return nil }
    }
    /// 首屏替换与分页合并只在完整读取成功后执行，不留下半页或空白占位。
    private func apply(_ rows: [ChatGroupNotice], replacing: Bool) {
        var map = replacing ? [:] : Dictionary(uniqueKeysWithValues: notices.map { ($0.id, $0) })
        for row in rows where !deletedIDs.contains(row.id) { map[row.id] = row }
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
    func close() { generation = UUID(); detailRevision = UUID(); roleRevision = UUID(); client.close(); notices = []; detail = nil; busy = false; hasMore = true; page = 1; managementRole = 0; deletedNoticeID = nil; deletedIDs = []; errorMessage = nil }
}
