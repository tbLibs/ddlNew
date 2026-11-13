import Foundation

@main struct Checks {
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let staged = root.appendingPathComponent("staged")
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        try Data([1,2,3]).write(to: staged.appendingPathComponent("media.jpg"))
        try Data([4]).write(to: staged.appendingPathComponent("thumbnail.jpg"))
        let input = VlogPrepared(directory: staged, kind: .photo, filename: "media.jpg", bytes: 3, width: 10, height: 20, duration: 0)
        let repository = VlogRepository(directory: root.appendingPathComponent("library"))
        let a = VlogOwner(tenantID: "tenant", userUID: "a")
        let b = VlogOwner(tenantID: "other", userUID: "a")
        let first = try await repository.insert(input, owner: a)
        precondition(first.count == 1)
        let second = try await repository.insert(input, owner: a)
        precondition(second.count == 2)
        let other = try await repository.load(owner: b); precondition(other.isEmpty)
        let removed = try await repository.remove(first[0].id, owner: a)
        precondition(removed.count == 1 && removed[0].id != first[0].id)
        let folder = try repository.folder(owner: a)
        precondition(!FileManager.default.fileExists(atPath: folder.appendingPathComponent(first[0].id.uuidString).path))
        try FileManager.default.removeItem(at: staged)
        let reloaded = try await VlogRepository(directory: root.appendingPathComponent("library")).load(owner: a)
        precondition(reloaded == removed)
        let savedBytes = try Data(contentsOf: folder.appendingPathComponent(removed[0].id.uuidString).appendingPathComponent("media.jpg")); precondition(savedBytes == Data([1,2,3]))
        // Missing input must never change the existing index or leave a new item directory.
        do { _ = try await repository.insert(input, owner: a); preconditionFailure("missing media accepted") } catch { }
        let unchanged = try await repository.load(owner: a); precondition(unchanged == removed)
        let children = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        precondition(children.filter { UUID(uuidString: $0) != nil }.count == 1)
        let cancellationGate = CancellationGate()
        let cancelled = Task { () throws -> [VlogRecord] in
            await cancellationGate.pause()
            return try await repository.insert(input, owner: a)
        }
        while !(await cancellationGate.waiting) { await Task.yield() }
        cancelled.cancel(); await cancellationGate.resume()
        do { _ = try await cancelled.value; preconditionFailure("cancelled insert committed") }
        catch { precondition(error is CancellationError) }
        let index = folder.appendingPathComponent("index.json")
        let indexData = try Data(contentsOf: index)
        var archive = try JSONSerialization.jsonObject(with: indexData) as! [String: Any]
        archive["schema"] = 2
        try JSONSerialization.data(withJSONObject: archive).write(to: index)
        do { _ = try await repository.load(owner: a); preconditionFailure("unknown schema accepted") } catch { }
        try indexData.write(to: index)
        try Data("broken".utf8).write(to: folder.appendingPathComponent("index.json"))
        do { _ = try await repository.load(owner: a); preconditionFailure("corrupt index became empty") } catch { }
        do { _ = try await repository.insert(input, owner: a); preconditionFailure("corrupt index overwritten") } catch { }
        let corrupt = try String(contentsOf: folder.appendingPathComponent("index.json"), encoding: .utf8); precondition(corrupt == "broken")
        let gate = DelayedRepository(root: root)
        let store = VlogStore(repository: gate)
        store.activate(tenantID: "tenant", userUID: "a")
        while !(await gate.waiting) { await Task.yield() }
        let oldEpoch = store.epoch
        store.activate(tenantID: "other", userUID: "b")
        while !store.ready { await Task.yield() }
        await gate.finish(with: removed)
        for _ in 0..<20 { await Task.yield() }
        precondition(store.records.isEmpty && store.owner?.userUID == "b" && oldEpoch != store.epoch)
        store.close(); precondition(!store.ready && store.owner == nil && store.records.isEmpty)
        print("Vlog account-switch late-load and logout checks passed")
        print("Vlog persistence, isolation, deletion, missing-input rollback and corruption checks passed")
    }
}

actor DelayedRepository: VlogPersisting {
    nonisolated let root: URL
    var pending: CheckedContinuation<[VlogRecord], Never>?
    var waiting: Bool { pending != nil }
    init(root: URL) { self.root = root }
    nonisolated func folder(owner: VlogOwner) throws -> URL { root }
    func load(owner: VlogOwner) async throws -> [VlogRecord] {
        if owner.userUID == "a" { return await withCheckedContinuation { pending = $0 } }
        return []
    }
    func finish(with records: [VlogRecord]) { pending?.resume(returning: records); pending = nil }
    func insert(_ prepared: VlogPrepared, owner: VlogOwner) async throws -> [VlogRecord] { [] }
    func remove(_ id: UUID, owner: VlogOwner) async throws -> [VlogRecord] { [] }
}

actor CancellationGate {
    var continuation: CheckedContinuation<Void, Never>?
    var waiting: Bool { continuation != nil }
    func pause() async { await withCheckedContinuation { continuation = $0 } }
    func resume() { continuation?.resume(); continuation = nil }
}
