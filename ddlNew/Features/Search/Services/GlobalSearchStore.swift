// Created by taobo on 2026/10/13.
import Foundation
import Combine

@MainActor final class GlobalSearchStore: ObservableObject {
    @Published private(set) var results: [GlobalSearchResult] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?
    private let client: any GlobalSearchClient
    private var userUID: String?
    private var generation = UUID()
    private var queryVersion = UUID()

    /// 注入本地搜索适配器，便于独立验证查询乱序。
    init(client: any GlobalSearchClient) { self.client = client }
    /// 每次打开搜索绑定当前登录身份，不复用上一账号结果。
    func prepare(userUID: String) { reset(); self.userUID = userUID }
    /// 输入改变立即失效旧查询，取消和失败不能删除后来查询的结果。
    func search(_ input: String) async {
        queryVersion = UUID()
        let version = queryVersion
        let runID = generation
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        results = []
        errorMessage = nil
        guard let uid = userUID, !query.isEmpty else { isSearching = false; return }
        isSearching = true
        defer { if generation == runID && queryVersion == version { isSearching = false } }
        do {
            let found = try await client.search(query, userUID: uid)
            guard generation == runID, queryVersion == version, !Task.isCancelled else { return }
            results = found
        } catch {
            guard generation == runID, queryVersion == version, !(error is CancellationError) else { return }
            errorMessage = "本地搜索失败，请重试"
        }
    }
    /// 页面离开或会话失效时清空全部用户结果。
    func clearQuery() {
        queryVersion = UUID(); results = []; isSearching = false; errorMessage = nil
    }
    /// 只有根登录生命周期可以撤销搜索所属身份。
    func reset() {
        generation = UUID(); queryVersion = UUID(); userUID = nil
        results = []; isSearching = false; errorMessage = nil
    }
}
