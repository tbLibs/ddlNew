// Created by taobo on 2026/10/13.
import Combine
import Foundation

@MainActor final class GroupApplicationsStore: ObservableObject {
    @Published private(set) var records: [GroupApplicationRecord] = []
    @Published var selectedIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var isReviewing = false
    @Published private(set) var hasMore = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var notice: String?
    private let client: any GroupApplicationsClient
    private var userUID: String?
    private var groupID: String?
    private var generation = UUID()
    private var queryVersion = UUID()
    private var page = 0
    private var pendingOnly = false
    private var pendingRefresh = false
    private var refreshTask: Task<Void, Never>?

    /// 客户端注入使分页和部分失败能够离线验证。
    init(client: any GroupApplicationsClient) { self.client = client }
    /// 页面绑定具体用户和可选群ID，离开后失效异步响应。
    func prepare(userUID: String, groupID: String?) { reset(); self.userUID = userUID; self.groupID = groupID }
    /// 筛选改变时保留旧数据到第一页成功，取消不会污染下一筛选。
    func reload(pendingOnly: Bool) async {
        pendingRefresh = false
        self.pendingOnly = pendingOnly
        queryVersion = UUID()
        isLoading = false
        await loadPage(1)
    }
    /// 事件与前台刷新合并，审核或当前读取期间不重复发起整页请求。
    func refresh() async {
        guard !isLoading, !isReviewing else { pendingRefresh = true; return }
        await reload(pendingOnly: pendingOnly)
    }
    /// 只在上一页完成且仍有更多时请求下一页。
    func loadMore() async { guard hasMore, !isLoading else { return }; await loadPage(page + 1) }
    /// 页码仅在成功后推进，并按申请ID合并重复记录。
    private func loadPage(_ nextPage: Int) async {
        guard let uid = userUID, !isLoading else { return }
        let runID = generation, version = queryVersion
        isLoading = true; errorMessage = nil
        defer {
            if generation == runID && queryVersion == version {
                isLoading = false
                schedulePendingRefresh()
            }
        }
        do {
            let result = try await client.load(userUID: uid, groupID: groupID, pendingOnly: pendingOnly, page: nextPage)
            guard generation == runID, queryVersion == version, !Task.isCancelled else { return }
            var seen: Set<String> = []
            records = ((nextPage == 1 ? [] : records) + result.records).filter { seen.insert($0.id).inserted }
            selectedIDs.formIntersection(Set(records.filter { $0.status == 1 }.map(\.id)))
            page = nextPage
            hasMore = !result.records.isEmpty && records.count < result.total
            if groupID == nil {
                try await client.markNotificationsRead(userUID: uid, snapshot: result.notifications)
                guard generation == runID, queryVersion == version, !Task.isCancelled else { return }
            }
        } catch {
            guard generation == runID, queryVersion == version, !(error is CancellationError) else { return }
            errorMessage = error.localizedDescription
        }
    }
    /// 全选仅包含可审核的申请，已处理记录不可重放。
    func selectAll() { selectedIDs = Set(records.filter { $0.status == 1 }.map(\.id)) }
    /// 防止重复提交，逐条结果提示后回查服务器状态。
    func review(accept: Bool) async {
        guard let uid = userUID, !isReviewing else { return }
        let selected = records.filter { $0.status == 1 && selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        let runID = generation
        isReviewing = true; errorMessage = nil; notice = nil
        defer { if generation == runID { isReviewing = false; schedulePendingRefresh() } }
        do {
            let outcome = try await client.review(userUID: uid, records: selected, accept: accept)
            guard generation == runID, !Task.isCancelled else { return }
            notice = "\(outcome.successfulIDs.count) 条处理成功，\(outcome.failedIDs.count) 条未成功，请刷新后重试"
            selectedIDs = []
            await reload(pendingOnly: pendingOnly)
        } catch {
            guard generation == runID, !(error is CancellationError) else { return }
            errorMessage = error.localizedDescription
        }
    }
    /// 读取或审核期间的同步事件合并为一次补读，不丢事件也不并发重刷。
    private func schedulePendingRefresh() {
        guard pendingRefresh, !isLoading, !isReviewing else { return }
        pendingRefresh = false
        let runID = generation, version = queryVersion
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self, self.generation == runID, self.queryVersion == version, !Task.isCancelled else { return }
            await self.refresh()
        }
    }
    /// 清除用户数据、选择和请求轮次，退出后不保留审核权。
    func reset() {
        refreshTask?.cancel(); refreshTask = nil; pendingRefresh = false
        generation = UUID(); queryVersion = UUID(); userUID = nil; groupID = nil
        records = []; selectedIDs = []; page = 0; hasMore = true
        isLoading = false; isReviewing = false; errorMessage = nil; notice = nil
    }
}
