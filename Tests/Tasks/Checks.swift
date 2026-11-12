import Foundation

actor ControlledTaskRepository: PersonalTaskPersisting {
    var rows: [TaskRecord] = []
    var failWrites = false
    var pauseLoad = false
    var continuation: CheckedContinuation<[TaskRecord], Error>?
    func configure(fail: Bool = false, pause: Bool = false) { failWrites = fail; pauseLoad = pause }
    func load(owner: TaskOwner) async throws -> [TaskRecord] {
        if pauseLoad { return try await withCheckedThrowingContinuation { continuation = $0 } }
        return rows
    }
    func save(_ records: [TaskRecord], owner: TaskOwner) throws {
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        rows = records
    }
    func release(_ records: [TaskRecord]) { continuation?.resume(returning: records); continuation = nil }
    var waiting: Bool { continuation != nil }
}

@main struct Checks {
    @MainActor static func until(_ predicate: () async -> Bool) async {
        for _ in 0..<1000 {
            if await predicate() { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        fatalError("Timed out")
    }
    @MainActor static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repo = TaskRepository(directory: folder)
        let a = TaskOwner(tenantID: "tenant-A", userUID: "user")
        let b = TaskOwner(tenantID: "tenant-B", userUID: "user")
        let c = TaskOwner(tenantID: "tenant-A", userUID: "another")
        var record = TaskRecord(); record.title = "Arrange materials"
        record.source = TaskSource(conversationID: "group", conversationName: "Team", messageID: "source", isGroup: true)
        record.dueDate = Date().addingTimeInterval(-60)
        precondition(record.isOverdue(at: Date()))
        var finished = record; finished.progress = .completed
        precondition(!finished.isOverdue(at: Date()))
        finished.progress = .cancelled; precondition(!finished.isOverdue(at: Date()))
        try await repo.save([record], owner: a)
        let reloaded = try await TaskRepository(directory: folder).load(owner: a)
        precondition(reloaded == [record])
        let otherTenant = try await repo.load(owner: b)
        let otherAccount = try await repo.load(owner: c)
        precondition(otherTenant.isEmpty && otherAccount.isEmpty)
        print("PASS: restart persistence, source/due date and tenant/account isolation")

        let legacySource = try JSONDecoder().decode(TaskSource.self, from: Data(#"{"groupID":"group","groupName":"Team","messageID":"source"}"#.utf8))
        precondition(legacySource.isGroupConversation && legacySource.belongsToGroup("group"))
        precondition(legacySource.conversationName == "Team" && legacySource.messageID == "source")
        var direct = TaskRecord(); direct.title = "Follow up with contact"
        direct.source = TaskSource(conversationID: "group", conversationName: "Contact", messageID: "direct-message", isGroup: false)
        try await repo.save([direct], owner: c)
        let restoredDirect = try await TaskRepository(directory: folder).load(owner: c)
        precondition(restoredDirect == [direct])
        precondition(restoredDirect[0].source?.isGroupConversation == false)
        precondition(restoredDirect[0].source?.belongsToGroup("group") == false)
        precondition(restoredDirect[0].source?.title == "来源单聊" && legacySource.title == "来源群聊")
        print("PASS: legacy group source compatibility and direct-chat persistence without group ID collisions")

        let store = PersonalTaskStore(repository: repo)
        store.activate(tenantID: a.tenantID, userUID: a.userUID)
        await until { store.ready }
        let epoch = store.epoch
        var updated = store.records[0]; updated.progress = .active
        let saved = await store.save(updated, expectedEpoch: epoch, creating: false)
        precondition(saved && store.records[0].changes.last?.progress == .active)
        let stale = await store.save(updated, expectedEpoch: epoch, creating: false)
        precondition(!stale && store.records[0].version == 1)
        var empty = TaskRecord(); empty.title = "   "
        let emptySaved = await store.save(empty, expectedEpoch: epoch, creating: true)
        precondition(!emptySaved)
        var long = TaskRecord(); long.title = String(repeating: "a", count: 81)
        let longSaved = await store.save(long, expectedEpoch: epoch, creating: true)
        precondition(!longSaved)
        store.close()
        let oldSessionSaved = await store.save(record, expectedEpoch: epoch, creating: false)
        precondition(!oldSessionSaved && store.records.isEmpty)
        store.activate(tenantID: b.tenantID, userUID: b.userUID)
        await until { store.ready }
        precondition(store.records.isEmpty)
        print("PASS: progress, stale edit rejection, validation and logout isolation")

        let url = try await repo.file(for: a)
        let broken = Data("broken file".utf8); try broken.write(to: url)
        store.activate(tenantID: a.tenantID, userUID: a.userUID)
        await until { store.errorMessage != nil }
        let corruptSaved = await store.save(record, expectedEpoch: store.epoch, creating: true)
        precondition(!store.ready && !corruptSaved)
        let preserved = try Data(contentsOf: url)
        precondition(preserved == broken)
        print("PASS: corrupt archive remains untouched and cannot be overwritten")

        let controlled = ControlledTaskRepository()
        let failingStore = PersonalTaskStore(repository: controlled)
        failingStore.activate(tenantID: "test", userUID: "test")
        await until { failingStore.ready }
        await controlled.configure(fail: true)
        let failed = await failingStore.save(record, expectedEpoch: failingStore.epoch, creating: true)
        precondition(!failed && failingStore.records.isEmpty && failingStore.errorMessage != nil)
        await controlled.configure()
        let accepted = await failingStore.save(record, expectedEpoch: failingStore.epoch, creating: true)
        precondition(accepted)
        let duplicate = await failingStore.save(record, expectedEpoch: failingStore.epoch, creating: true)
        precondition(!duplicate && failingStore.records.count == 1)
        let deleted = await failingStore.remove(id: record.id, expectedEpoch: failingStore.epoch)
        precondition(deleted && failingStore.records.isEmpty)
        print("PASS: failed writes preserve UI state, duplicate create rejected, deletion saved")

        await controlled.configure(pause: true)
        failingStore.activate(tenantID: "old", userUID: "user")
        await until { await controlled.waiting }
        failingStore.close()
        await controlled.release([record])
        try? await Task.sleep(nanoseconds: 10_000_000)
        precondition(failingStore.records.isEmpty && !failingStore.ready)
        print("PASS: late load cannot restore data after logout")
    }
}
