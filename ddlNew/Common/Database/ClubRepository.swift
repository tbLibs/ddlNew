//
//  ClubRepository.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation
import WCDBSwift

/// 俱乐部展示状态的本地数据库，数据库操作不占用主线程。
actor ClubRepository {
    private var database: Database?
    private func open() throws -> Database {
        if let database { return database }
        var directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ClubMember", isDirectory: true)
        #if DEBUG
        // 测试数据库按 UUID 隔离，同时保留重启后的持久化验证。
        if let value = ProcessInfo.processInfo.environment["CLUB_UI_TEST_DATABASE_ID"], let id = UUID(uuidString: value) {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("ClubTests-\(id.uuidString)", isDirectory: true)
        }
        #endif
        let protection: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: protection)
        try FileManager.default.setAttributes(protection, ofItemAtPath: directory.path)
        // 新建文件和历史数据库文件都采用相同的数据保护策略。
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            where file.lastPathComponent.hasPrefix("membership.sqlite") {
            try FileManager.default.setAttributes(protection, ofItemAtPath: file.path)
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        let db = Database(at: directory.appendingPathComponent("membership.sqlite").path)
        try db.create(table: "member_state", of: ClubStateRow.self)
        database = db
        return db
    }
    func load() throws -> ClubSnapshot {
        let row: ClubStateRow? = try open().getObject(fromTable: "member_state")
        guard let row, let data = row.payload.data(using: .utf8) else { return ClubSnapshot() }
        return try JSONDecoder().decode(ClubSnapshot.self, from: data)
    }
    func save(_ snapshot: ClubSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        let row = ClubStateRow()
        row.payload = String(decoding: data, as: UTF8.self)
        try open().insertOrReplace(row, intoTable: "member_state")
    }
}
