//
//  MassMessageStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/23.
//

import Foundation
import Combine

@MainActor final class MassMessageStore: ObservableObject {
    let context: ChatContext
    @Published private(set) var records: [MassMessageRecord] = []
    @Published private(set) var loading = false
    @Published private(set) var hasMore = true
    @Published var errorMessage: String?
    @Published var feedback: String?
    @Published private(set) var deleting: Set<String> = []
    private let client: any MassMessageClient
    private let isCurrent: @MainActor (ChatContext) -> Bool
    private let updatePreview: ([MassMessageRecord]) -> Void
    private var page = 0
    private var generation = UUID()
    private var deleted: Set<String> = []

    init(context: ChatContext, client: (any MassMessageClient)? = nil,
         isCurrent: @escaping @MainActor (ChatContext) -> Bool = { ChatRuntime.shared.isCurrent($0) },
         updatePreview: (([MassMessageRecord]) -> Void)? = nil) {
        self.context = context; self.client = client ?? SDKMassMessageClient(context: context); self.isCurrent = isCurrent
        self.updatePreview = updatePreview ?? { SDKMassMessagePreview.update($0, context: context) }
        ChatRuntime.shared.registerCleanup(owner: self) { [weak self] in self?.close() }
    }
    /// 刷新和分页共享在途守卫，页码只在成功时前进。
    func reload() async { await load(reset: true) }
    func loadMore() async { guard hasMore else { return }; await load(reset: false) }
    private func load(reset: Bool) async {
        guard !loading, isCurrent(context) else { return }
        loading = true; errorMessage = nil
        let run = generation, next = reset ? 1 : page + 1
        defer { if generation == run { loading = false } }
        do {
            let result = try await client.load(page: next)
            guard run == generation, isCurrent(context), !Task.isCancelled else { return }
            var unique: [String: MassMessageRecord] = [:]
            for record in (reset ? [] : records) + result.records where !deleted.contains(record.id) { unique[record.id] = record }
            records = unique.values.sorted { $0.sentAt == $1.sentAt ? $0.id > $1.id : $0.sentAt > $1.sentAt }
            page = next; hasMore = result.hasMore(page: next)
            updatePreview(records)
        } catch { if run == generation, isCurrent(context), !(error is CancellationError) { errorMessage = error.localizedDescription } }
    }
    /// 服务端删除确认后移除本条，迟到分页不得把它放回来。
    func delete(_ record: MassMessageRecord) async -> Bool {
        guard !deleting.contains(record.id), isCurrent(context) else { return false }
        deleting.insert(record.id); errorMessage = nil; feedback = nil
        let run = generation
        defer { if run == generation { deleting.remove(record.id) } }
        do {
            try await client.delete(record)
            guard run == generation, isCurrent(context) else { return false }
            deleted.insert(record.id); records.removeAll { $0.id == record.id }
            if !records.isEmpty || !hasMore { updatePreview(records) }
            feedback = "已删除群发记录"
            if records.isEmpty && hasMore { await reload() }
            return true
        } catch { if run == generation, isCurrent(context), !(error is CancellationError) { errorMessage = error.localizedDescription }; return false }
    }
    /// 根认证失效时清空正文并取消全部等待。
    func close() { generation = UUID(); client.cancel(); records = []; loading = false; deleting = []; deleted = []; page = 0; hasMore = true; errorMessage = nil; feedback = nil }
}
