import Foundation
import CryptoKit

protocol PersonalTaskPersisting: Actor {
    func load(owner: TaskOwner) async throws -> [TaskRecord]
    func save(_ records: [TaskRecord], owner: TaskOwner) async throws
}

/// 独立账号目录，原子替换文件。损坏和未知版本绝不作为空列表覆盖。
actor TaskRepository: PersonalTaskPersisting {
    private let directory: URL
    private nonisolated struct Archive: Codable {
        var schema = 1
        let owner: TaskOwner
        let records: [TaskRecord]
    }
    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PersonalTasks", isDirectory: true)) {
        self.directory = directory
    }
    func file(for owner: TaskOwner) throws -> URL {
        let key = try JSONEncoder().encode([owner.tenantID, owner.userUID])
        let hash = SHA256.hash(data: key).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(hash).appendingPathExtension("json")
    }
    func load(owner: TaskOwner) throws -> [TaskRecord] {
        let url = try file(for: owner)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let archive: Archive
        do { archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: url)) }
        catch { throw TaskStorageError.invalidArchive }
        guard archive.schema == 1, archive.owner == owner,
              Set(archive.records.map(\.id)).count == archive.records.count else { throw TaskStorageError.invalidArchive }
        return archive.records
    }
    func save(_ records: [TaskRecord], owner: TaskOwner) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Archive(owner: owner, records: records))
        #if os(iOS)
        try data.write(to: file(for: owner), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: file(for: owner), options: .atomic)
        #endif
    }
}
