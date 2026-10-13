//
//  ApplicationsSearchChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

@MainActor final class AcceptanceApplicationsClient: GroupApplicationsClient {
    var pages: [Int: GroupApplicationsPage] = [:]
    var loads: [Int] = []
    var failPage: Int?
    var delay = false
    var waits: [CheckedContinuation<GroupApplicationsPage, Error>] = []
    var reviewWait: CheckedContinuation<GroupApplicationOutcome, Error>?
    var delayReview = false
    var canReview = true
    var reviewCalls = 0
    var pauseFirstLoad = false
    var firstLoad: CheckedContinuation<GroupApplicationsPage, Error>?
    /// 页码与筛选均可延迟，让旧数据在新请求后返回。
    func load(userUID: String, groupID: String?, pendingOnly: Bool, page: Int) async throws -> GroupApplicationsPage {
        loads.append(page)
        if pauseFirstLoad { pauseFirstLoad = false; return try await withCheckedThrowingContinuation { firstLoad = $0 } }
        if failPage == page { throw CocoaError(.fileReadUnknown) }
        if delay { return try await withCheckedThrowingContinuation { waits.append($0) } }
        return pages[page] ?? GroupApplicationsPage(records: [], total: 0)
    }
    /// 提交时角色重新校验，结果支持部分成功和迟到。
    func review(userUID: String, records: [GroupApplicationRecord], accept: Bool) async throws -> GroupApplicationOutcome {
        guard canReview else { throw CocoaError(.fileReadNoPermission) }; reviewCalls += 1
        if delayReview { return try await withCheckedThrowingContinuation { reviewWait = $0 } }
        return GroupApplicationOutcome(successfulIDs: ["a0"], failedIDs: Set(records.filter { $0.id != "a0" }.map(\.id)))
    }
}
@MainActor final class AcceptanceSearchClient: GlobalSearchClient {
    var waits: [CheckedContinuation<[GlobalSearchResult], Error>] = []
    /// 保留所有查询请求，不以关键字字典覆盖重复同词的continuation。
    func search(_ query: String, userUID: String) async throws -> [GlobalSearchResult] { try await withCheckedThrowingContinuation { waits.append($0) } }
}

@main struct ApplicationsSearchChecks {
    @MainActor static var count = 0
    /// 生产群申请Store覆盖10页边界、失败重试、筛选反序、部分结果、角色收回和同UID重登。
    @MainActor static func main() async {
        let client = AcceptanceApplicationsClient(); let store = GroupApplicationsStore(client: client)
        client.pages[1] = page(0..<10, total: 21); client.pages[2] = page(9..<19, total: 21); client.pages[3] = page(19..<21, total: 21)
        store.prepare(userUID: "qa-me", groupID: "qa-group"); await store.reload(pendingOnly: false)
        check(store.records.count == 10 && store.hasMore, "M-021 群申请第1页10条")
        client.failPage = 2; await store.loadMore()
        check(store.records.count == 10 && store.errorMessage != nil, "M-021 分页失败保留现有记录")
        client.failPage = nil; await store.loadMore()
        check(client.loads.suffix(2) == [2, 2] && store.records.count == 19, "M-021 分页失败重试不跳页并去重")
        await store.loadMore(); check(store.records.count == 21 && !store.hasMore, "M-021 不足10条尾页结束")
        store.selectAll(); await store.review(accept: true)
        check(store.notice?.contains("1 条处理成功，20 条未成功") == true, "M-021 批量部分成功保留逐项计数")
        store.selectAll(); client.canReview = false; let previous = client.reviewCalls; await store.review(accept: false)
        check(client.reviewCalls == previous && store.errorMessage != nil && !store.selectedIDs.isEmpty, "CHAT-041 角色收回不审核且可恢复选择")
        client.canReview = true; client.delay = true
        let oldFilter = Task { await store.reload(pendingOnly: false) }
        while client.waits.isEmpty { await Task.yield() }
        let newFilter = Task { await store.reload(pendingOnly: true) }
        while client.waits.count < 2 { await Task.yield() }
        client.waits[1].resume(returning: page(50..<51, total: 1)); await newFilter.value
        client.waits[0].resume(returning: page(60..<62, total: 2)); await oldFilter.value
        check(store.records.map(\.id) == ["a50"], "M-021 旧全部筛选迟到不覆盖新待审")
        client.delay = false; client.delayReview = true; store.selectAll()
        let stale = Task { await store.review(accept: true) }
        while client.reviewWait == nil { await Task.yield() }
        store.prepare(userUID: "qa-me", groupID: "other-group")
        client.reviewWait?.resume(returning: GroupApplicationOutcome(successfulIDs: ["a50"], failedIDs: [])); await stale.value
        check(store.records.isEmpty && store.notice == nil && !store.isReviewing, "M-G4 同UID新会话旧审核回执失效")
        client.delayReview = false; client.pages[1] = GroupApplicationsPage(records: [record(1, status: 1), record(2, status: 4)], total: 2)
        await store.reload(pendingOnly: false); store.selectAll()
        check(store.selectedIDs == ["a1"], "CHAT-041 已处理记录不可选")
        client.pages[1] = GroupApplicationsPage(records: [record(1, status: 5), record(2, status: 4)], total: 2)
        await store.reload(pendingOnly: false)
        check(store.selectedIDs.isEmpty, "CHAT-041 他端审核后及时移出旧选择")
        let searchClient = AcceptanceSearchClient(); let search = GlobalSearchStore(client: searchClient)
        search.prepare(userUID: "qa-me")
        let beforeLeave = Task { await search.search("same") }
        while searchClient.waits.isEmpty { await Task.yield() }
        search.clearQuery()
        searchClient.waits[0].resume(returning: [searchRecord("old")]); await beforeLeave.value
        check(search.results.isEmpty && !search.isSearching, "M-016 离页清查询拒绝迟到结果")
        let afterReturn = Task { await search.search("same") }
        while searchClient.waits.count < 2 { await Task.yield() }
        searchClient.waits[1].resume(returning: [searchRecord("return")]); await afterReturn.value
        check(search.results.map(\.id) == ["return"], "M-016 返回搜索仍保留根身份可查询")
        let oldLogin = Task { await search.search("same") }
        while searchClient.waits.count < 3 { await Task.yield() }
        search.prepare(userUID: "qa-me")
        searchClient.waits[2].resume(returning: [searchRecord("old-login")]); await oldLogin.value
        check(search.results.isEmpty, "M-G4 同UID重新AUTH旧搜索不能回流")
        let cleared = Task { await search.search("query") }
        while searchClient.waits.count < 4 { await Task.yield() }
        await search.search(" \n ")
        searchClient.waits[3].resume(returning: [searchRecord("clear")]); await cleared.value
        check(search.results.isEmpty && !search.isSearching, "M-016 空白清查询后拒绝旧结果")
        let eventClient = AcceptanceApplicationsClient(); let eventStore = GroupApplicationsStore(client: eventClient)
        eventClient.pauseFirstLoad = true; eventClient.pages[1] = page(101..<102, total: 1)
        eventStore.prepare(userUID: "qa-me", groupID: "qa-event-group")
        let initial = Task { await eventStore.reload(pendingOnly: false) }
        while eventClient.firstLoad == nil { await Task.yield() }
        await eventStore.refresh()
        eventClient.firstLoad?.resume(returning: page(100..<101, total: 1)); await initial.value
        for _ in 0..<100 { await Task.yield() }
        check(eventClient.loads.count == 2 && eventStore.records.map(\.id) == ["a101"], "M-021 加载期间同步事件必须合并一次补读")
        eventClient.delayReview = true; eventStore.selectAll()
        let reviewFailure = Task { await eventStore.review(accept: true) }
        while eventClient.reviewWait == nil { await Task.yield() }
        eventClient.pages[1] = page(102..<103, total: 1)
        await eventStore.refresh(); await eventStore.refresh()
        eventClient.reviewWait?.resume(throwing: CocoaError(.fileReadNoPermission)); await reviewFailure.value
        for _ in 0..<100 { await Task.yield() }
        check(eventClient.loads.count == 3 && eventStore.records.map(\.id) == ["a102"] && !eventStore.isReviewing, "M-021 审核失败期间多个同步事件合并一次补读")
        print("Independent applications/search acceptance: \(count)/\(count) passed")
    }
    /// 匿名申请样本只表明页边界与状态，不含真实群关系。
    static func record(_ id: Int, status: Int = 1) -> GroupApplicationRecord { GroupApplicationRecord(id: "a\(id)", groupID: "qa-group", nickname: "匿名申请", reason: "验收", status: status) }
    /// 构造固定十条或不足十条的真实Store输入合同。
    static func page(_ range: Range<Int>, total: Int) -> GroupApplicationsPage { GroupApplicationsPage(records: range.map { record($0) }, total: total) }
    /// 搜索结果使用稳定匿名ID，重复正文不能替代原消息定位。
    static func searchRecord(_ id: String) -> GlobalSearchResult { GlobalSearchResult(id: id, kind: .friend, peerID: "qa-peer", title: "匿名结果", detail: "", avatar: "", messageID: nil, date: nil) }
    /// 任意不符立即终止脚本，避免假通过汇总。
    @MainActor static func check(_ result: Bool, _ label: String) { precondition(result, label); count += 1; print("PASS \(label)") }
}
