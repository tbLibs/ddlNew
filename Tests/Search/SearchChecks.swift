import Foundation
@MainActor private final class SearchClient: GlobalSearchClient {
    var pending: [String: CheckedContinuation<[GlobalSearchResult], Error>] = [:]
    /// 暂停不同关键字的请求以验证乱序返回。
    func search(_ query: String, userUID: String) async throws -> [GlobalSearchResult] {
        try await withCheckedThrowingContinuation { pending[query] = $0 }
    }
}
@main private struct SearchChecks {
    /// 检查旧查询、退出和空输入不会覆盖新结果。
    @MainActor static func main() async {
        let client = SearchClient()
        let store = GlobalSearchStore(client: client)
        store.prepare(userUID: "A")
        let old = Task { await store.search("old") }
        while client.pending["old"] == nil { await Task.yield() }
        let recent = Task { await store.search("new") }
        while client.pending["new"] == nil { await Task.yield() }
        let result = GlobalSearchResult(id: "f", kind: .friend, peerID: "f", title: "new", detail: "", avatar: "", messageID: nil, date: nil)
        client.pending["new"]?.resume(returning: [result])
        await recent.value
        client.pending["old"]?.resume(returning: [])
        await old.value
        precondition(store.results.map(\.id) == ["f"], "旧关键字结果不能覆盖当前结果")
        let late = Task { await store.search("late") }
        while client.pending["late"] == nil { await Task.yield() }
        store.reset()
        client.pending["late"]?.resume(returning: [result])
        await late.value
        precondition(store.results.isEmpty && !store.isSearching && store.errorMessage == nil)
        print("Global search checks passed")
    }
}
