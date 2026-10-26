//
//  MassMessageRecipientsStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/23.
//

import Foundation
import Combine

@MainActor final class MassMessageRecipientsStore: ObservableObject {
    @Published private(set) var recipients: [MassMessageRecipient] = []
    @Published private(set) var loading = false
    @Published private(set) var hasMore = true
    @Published var errorMessage: String?
    private let context: ChatContext
    private let record: MassMessageRecord
    private let failures: Bool
    private let client: any MassMessageClient
    private let isCurrent: @MainActor (ChatContext) -> Bool
    private var page = 0
    private var generation = UUID()
    init(context: ChatContext, record: MassMessageRecord, failures: Bool, client: (any MassMessageClient)? = nil,
         isCurrent: @escaping @MainActor (ChatContext) -> Bool = { ChatRuntime.shared.isCurrent($0) }) {
        self.context = context; self.record = record; self.failures = failures
        self.client = client ?? SDKMassMessageClient(context: context); self.isCurrent = isCurrent
        ChatRuntime.shared.registerCleanup(owner: self) { [weak self] in self?.close() }
    }
    func reload() async { await load(reset: true) }
    func loadMore() async { guard hasMore else { return }; await load(reset: false) }
    private func load(reset: Bool) async {
        guard !loading, isCurrent(context) else { return }
        let run = generation, next = reset ? 1 : page + 1
        loading = true; errorMessage = nil
        defer { if run == generation { loading = false } }
        do {
            let result = try await client.recipients(record: record, failures: failures, page: next)
            guard run == generation, isCurrent(context), !Task.isCancelled else { return }
            var values = reset ? [] : recipients
            for recipient in result.records {
                if let index = values.firstIndex(where: { $0.id == recipient.id }) { values[index] = recipient } else { values.append(recipient) }
            }
            recipients = values; page = next; hasMore = result.hasMore(page: next)
        } catch { if run == generation, isCurrent(context), !(error is CancellationError) { errorMessage = error.localizedDescription } }
    }
    func close() { generation = UUID(); client.cancel(); recipients = []; page = 0; loading = false; hasMore = true; errorMessage = nil }
}
