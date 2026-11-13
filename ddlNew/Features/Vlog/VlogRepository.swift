import Foundation
import CryptoKit

protocol VlogPersisting: Actor {
    nonisolated func folder(owner: VlogOwner) throws -> URL
    func load(owner: VlogOwner) async throws -> [VlogRecord]
    func insert(_ prepared: VlogPrepared, owner: VlogOwner) async throws -> [VlogRecord]
    func remove(_ id: UUID, owner: VlogOwner) async throws -> [VlogRecord]
}

/// Media is copied before the index commits. A failed insert removes only its own directory.
actor VlogRepository: VlogPersisting {
    private nonisolated let directory: URL
    private nonisolated struct Archive: Codable {
        var schema = 1
        let owner: VlogOwner
        let records: [VlogRecord]
    }
    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Vlog", isDirectory: true)) {
        self.directory = directory
    }
    nonisolated func folder(owner: VlogOwner) throws -> URL {
        let data = try JSONEncoder().encode([owner.tenantID, owner.userUID])
        let key = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(key, isDirectory: true)
    }
    func load(owner: VlogOwner) throws -> [VlogRecord] {
        let index = try folder(owner: owner).appendingPathComponent("index.json")
        guard FileManager.default.fileExists(atPath: index.path) else { return [] }
        guard let archive = try? JSONDecoder().decode(Archive.self, from: Data(contentsOf: index)),
              archive.schema == 1, archive.owner == owner,
              Set(archive.records.map(\.id)).count == archive.records.count,
              archive.records.allSatisfy(\.valid) else { throw VlogError.invalidArchive }
        return archive.records
    }
    func insert(_ prepared: VlogPrepared, owner: VlogOwner) throws -> [VlogRecord] {
        try Task.checkCancellation()
        let records = try load(owner: owner)
        let record = VlogRecord(id: UUID(), createdAt: Date(), kind: prepared.kind,
            filename: prepared.filename, bytes: prepared.bytes, width: prepared.width, height: prepared.height, duration: prepared.duration)
        guard record.valid else { throw VlogError.invalidMedia }
        let root = try folder(owner: owner)
        let destination = root.appendingPathComponent(record.id.uuidString, isDirectory: true)
        var committed = false
        defer { if !committed { try? FileManager.default.removeItem(at: destination) } }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: destination.path)
        #endif
        for name in [record.filename, "thumbnail.jpg"] {
            let source = prepared.directory.appendingPathComponent(name)
            guard let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 else { throw VlogError.invalidMedia }
            if name == record.filename, Int64(size) != record.bytes { throw VlogError.invalidMedia }
            try FileManager.default.copyItem(at: source, to: destination.appendingPathComponent(name))
        }
        try Task.checkCancellation()
        let next = [record] + records
        try save(next, owner: owner)
        committed = true
        return next
    }
    func remove(_ id: UUID, owner: VlogOwner) throws -> [VlogRecord] {
        try Task.checkCancellation()
        let records = try load(owner: owner)
        guard records.contains(where: { $0.id == id }) else { throw VlogError.missing }
        let next = records.filter { $0.id != id }
        try save(next, owner: owner)
        // The index is authoritative; failure to reclaim disk space must not resurrect a deleted work.
        try? FileManager.default.removeItem(at: folder(owner: owner).appendingPathComponent(id.uuidString))
        return next
    }
    private func save(_ records: [VlogRecord], owner: VlogOwner) throws {
        let data = try JSONEncoder().encode(Archive(owner: owner, records: records))
        let index = try folder(owner: owner).appendingPathComponent("index.json")
        #if os(iOS)
        try data.write(to: index, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: index, options: .atomic)
        #endif
    }
}
