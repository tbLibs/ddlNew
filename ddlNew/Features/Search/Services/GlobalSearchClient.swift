// Created by taobo on 2026/10/13.
import Foundation

@MainActor protocol GlobalSearchClient: AnyObject {
    /// 查询 SDK 本地好友、群和全文消息缓存，不假称服务器全历史搜索。
    func search(_ query: String, userUID: String) async throws -> [GlobalSearchResult]
}
