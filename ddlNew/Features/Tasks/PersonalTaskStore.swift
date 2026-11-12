import Foundation
import Combine

@MainActor final class PersonalTaskStore: ObservableObject {
    static let shared = PersonalTaskStore()
    @Published private(set) var records: [TaskRecord] = []
    @Published private(set) var epoch = UUID()
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published var errorMessage: String?
    private(set) var owner: TaskOwner?
    private let repository: any PersonalTaskPersisting

    init(repository: any PersonalTaskPersisting = TaskRepository()) { self.repository = repository }

    func activate(tenantID: String, userUID: String) {
        close()
        guard !tenantID.isEmpty, !userUID.isEmpty else { return }
        owner = TaskOwner(tenantID: tenantID, userUID: userUID)
        Task { await reload() }
    }
    func close() {
        epoch = UUID(); owner = nil; records = []; ready = false; busy = false; errorMessage = nil
    }
    func reload() async {
        guard let owner, !busy else { return }
        let run = epoch; busy = true; errorMessage = nil
        defer { if epoch == run { busy = false } }
        do {
            let loaded = try await repository.load(owner: owner)
            guard epoch == run else { return }
            records = loaded; ready = true
        } catch {
            guard epoch == run else { return }
            ready = false; report(error)
        }
    }
    @discardableResult
    func save(_ draft: TaskRecord, expectedEpoch: UUID, creating: Bool) async -> Bool {
        guard ready, !busy, epoch == expectedEpoch, let owner else { return false }
        var next = records
        do {
            var record = try draft.validated()
            if creating {
                guard !next.contains(where: { $0.id == record.id }) else { throw TaskStorageError.changed }
                record.createdAt = Date()
                record.changes = [TaskChange(progress: record.progress)]
                next.append(record)
            } else {
                guard let index = next.firstIndex(where: { $0.id == record.id }) else { throw TaskStorageError.missing }
                let old = next[index]
                guard old.version == record.version else { throw TaskStorageError.changed }
                record.createdAt = old.createdAt
                record.changes = old.changes
                if old.progress != record.progress { record.changes.append(TaskChange(progress: record.progress)) }
                record.changes = Array(record.changes.suffix(200))
                next[index] = record
            }
            guard let index = next.firstIndex(where: { $0.id == record.id }) else { throw TaskStorageError.missing }
            next[index].updatedAt = Date(); next[index].version += 1
            return await persist(next, owner: owner, run: expectedEpoch)
        } catch { report(error); return false }
    }
    func remove(id: UUID, expectedEpoch: UUID) async -> Bool {
        guard ready, !busy, epoch == expectedEpoch, let owner,
              records.contains(where: { $0.id == id }) else { return false }
        return await persist(records.filter { $0.id != id }, owner: owner, run: expectedEpoch)
    }
    private func persist(_ next: [TaskRecord], owner: TaskOwner, run: UUID) async -> Bool {
        busy = true; errorMessage = nil
        defer { if epoch == run { busy = false } }
        do {
            try await repository.save(next, owner: owner)
            guard epoch == run else { return false }
            records = next; return true
        } catch { if epoch == run { report(error) }; return false }
    }
    private func report(_ error: Error) {
        errorMessage = L10n.lookup((error as? TaskStorageError)?.message ?? "事项保存失败，请重试")
    }
}
