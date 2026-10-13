//
//  ChatStickersStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import Foundation
import Combine

@MainActor final class ChatStickersStore: ObservableObject {
    @Published private(set) var stickers: [ChatSticker] = []
    @Published private(set) var busy = false
    @Published private(set) var hasMore = false
    @Published var errorMessage: String?
    private let client: any ChatStickersClient
    private var context: ChatContext?
    private var page = 1
    private var generation = UUID()
    /// 注入客户端验证分页与取消，界面不直接依赖SDK。
    init(client: any ChatStickersClient) { self.client = client }
    /// 新身份先清旧资源，再加载真实首批。
    func open(_ context: ChatContext) async { close(); self.context = context; await loadMore() }
    /// 失败保留分页位置，重复资源按UID与URL去重。
    func loadMore() async {
        guard let context, !busy else { return }; let run = generation
        busy = true; errorMessage = nil; defer { if generation == run { busy = false } }
        do { let result = try await client.load(context: context, page: page); guard generation == run, !Task.isCancelled else { return }
            var keys = Set(stickers.map { $0.id }); stickers += result.stickers.filter { keys.insert($0.id).inserted }; hasMore = result.hasMore; page += 1
        } catch { if generation == run { errorMessage = error.localizedDescription } }
    }
    /// 关闭不保留上一账号的表情资源与错误。
    func close() { generation = UUID(); client.close(); context = nil; stickers = []; busy = false; hasMore = false; page = 1; errorMessage = nil }
}
