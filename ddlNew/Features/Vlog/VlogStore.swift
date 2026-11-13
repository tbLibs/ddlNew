import Foundation
import Combine

@MainActor final class VlogStore: ObservableObject {
    static let shared = VlogStore()
    @Published private(set) var records: [VlogRecord] = []
    @Published private(set) var epoch = UUID()
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published var errorMessage: String?
    private(set) var owner: VlogOwner?
    private let repository: any VlogPersisting
    private var loading: Task<Void, Never>?

    init(repository: any VlogPersisting = VlogRepository()) { self.repository = repository }
    func activate(tenantID: String, userUID: String) {
        close()
        guard !tenantID.isEmpty, !userUID.isEmpty else { return }
        owner = VlogOwner(tenantID: tenantID, userUID: userUID)
        loading = Task { await reload() }
    }
    func close() {
        loading?.cancel(); loading = nil
        owner = nil; epoch = UUID(); records = []; ready = false; busy = false; errorMessage = nil
    }
    func reload() async {
        guard let owner, !busy else { return }
        let run = epoch; busy = true
        defer { if run == epoch { busy = false } }
        do {
            let records = try await repository.load(owner: owner)
            guard run == epoch, !Task.isCancelled else { return }
            self.records = records; ready = true; errorMessage = nil
        } catch { if run == epoch { ready = false; report(error) } }
    }
    func importPrepared(_ prepared: VlogPrepared, expectedEpoch: UUID) async -> Bool {
        guard expectedEpoch == epoch, ready, !busy, let owner, !Task.isCancelled else { return false }
        busy = true; errorMessage = nil
        defer { if expectedEpoch == epoch { busy = false } }
        do {
            let records = try await repository.insert(prepared, owner: owner)
            guard expectedEpoch == epoch else { return false }
            self.records = records; return true
        } catch { if expectedEpoch == epoch, !(error is CancellationError) { report(error) }; return false }
    }
    func remove(_ id: UUID, expectedEpoch: UUID) async -> Bool {
        guard expectedEpoch == epoch, ready, !busy, let owner else { return false }
        busy = true; errorMessage = nil
        defer { if expectedEpoch == epoch { busy = false } }
        do {
            let records = try await repository.remove(id, owner: owner)
            guard expectedEpoch == epoch else { return false }
            self.records = records; return true
        } catch { if expectedEpoch == epoch { report(error) }; return false }
    }
    func file(_ record: VlogRecord, thumbnail: Bool = false) -> URL? {
        guard ready, let owner, records.contains(where: { $0.id == record.id }), let folder = try? repository.folder(owner: owner) else { return nil }
        return folder.appendingPathComponent(record.id.uuidString).appendingPathComponent(thumbnail ? "thumbnail.jpg" : record.filename)
    }
    private func report(_ error: Error) {
        errorMessage = L10n.tr(error as? VlogError == .invalidArchive ? "作品数据无法读取，请重试；原文件已保留。" : "作品保存或读取失败，请检查存储空间后重试。")
    }
}
