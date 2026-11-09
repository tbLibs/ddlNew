//
//  MiniAppsStore.swift
//  ddlNew
//
//  Created by taobo on 2026/11/09.
//
import Foundation
import Combine
@MainActor final class MiniAppsStore: ObservableObject {
    @Published private(set) var items: [MiniAppRecord] = []
    @Published private(set) var hasLoaded = false
    @Published private(set) var isLoading = false
    @Published private(set) var isBusy = false
    @Published private(set) var feedback: String?
    @Published private(set) var hasMore = true
    private let context: ChatContext
    private let client: any MiniAppClient
    private let isCurrent: (ChatContext) -> Bool
    private var epoch = UUID()
    private var pageEpoch = UUID()
    private var page = 0
    private var closed = false
    init(context: ChatContext, client: any MiniAppClient, isCurrent: @escaping (ChatContext) -> Bool) {
        self.context = context; self.client = client; self.isCurrent = isCurrent
    }
    private func valid(_ token: UUID) throws {
        try Task.checkCancellation()
        guard !closed, epoch == token, isCurrent(context) else { throw CancellationError() }
    }
    func refresh() async { _ = await load(1) }
    func loadMore() async { guard hasMore else { return }; _ = await load(page + 1) }
    private func load(_ target: Int, afterMutation: Bool = false) async -> Bool {
        guard !closed, !isLoading, (!isBusy || afterMutation), isCurrent(context) else { return false }
        let token = epoch; let request = UUID(); pageEpoch = request
        isLoading = true; feedback = nil
        defer { if pageEpoch == request { isLoading = false } }
        do {
            let result = try await client.list(page: target, context: context)
            try valid(token); guard pageEpoch == request else { return false }
            let records = result.items
            var seen = Set<String>(); let source = target == 1 ? records : items + records
            items = source.filter { seen.insert($0.id).inserted }
            hasLoaded = true; page = target; hasMore = result.hasMore
            return true
        } catch { if pageEpoch == request { report(error, token) }; return false }
    }
    func save(_ draft: MiniAppDraft, editing: MiniAppRecord? = nil, iconFile: URL? = nil) async -> Bool {
        defer { if let iconFile { try? FileManager.default.removeItem(at: iconFile) } }
        guard editing?.canEdit != false else { return false }
        if let message = draft.validationMessage { feedback = message; return false }
        let token = epoch
        return await mutate {
            var value = draft
            if let iconFile { value.icon = try await self.client.upload(iconFile, context: self.context); try self.valid(token) }
            try await self.client.save(value, editing: editing, context: self.context)
        }
    }
    func delete(_ record: MiniAppRecord) async -> Bool {
        guard record.canDelete else { return false }
        let success = await mutate { try await self.client.delete(record, context: self.context) }
        if success { items.removeAll { $0.id == record.id } }
        return success
    }
    private func mutate(_ body: () async throws -> Void) async -> Bool {
        guard !closed, !isBusy, isCurrent(context) else { return false }
        let token = epoch; pageEpoch = UUID(); isLoading = false; isBusy = true; feedback = nil
        do {
            try valid(token); try await body(); try valid(token)
            let refreshed = await load(1, afterMutation: true)
            try valid(token)
            isBusy = false
            if !refreshed { feedback = "操作已完成，列表刷新失败，请刷新重试" }
            return true
        }
        catch { if epoch == token { isBusy = false }; report(error, token); return false }
    }
    func detail(id: String, password: String = "") async throws -> MiniAppRecord {
        let token = epoch; try valid(token)
        let record = try await client.detail(id: id, password: password, context: context)
        try valid(token); return record
    }
    func unlock(_ record: MiniAppRecord, password: String) async -> MiniAppRecord? {
        let token = epoch
        do { return try await detail(id: record.id, password: password) } catch { report(error, token); return nil }
    }
    private func report(_ error: Error, _ token: UUID) {
        guard epoch == token, !closed, isCurrent(context), !(error is CancellationError) else { return }
        feedback = error.localizedDescription
    }
    func close() { closed = true; epoch = UUID(); pageEpoch = UUID(); client.cancel(); items = []; isBusy = false; isLoading = false; feedback = nil }
}
