//
//  SystemConfigStore.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import CryptoKit
import Foundation
import ObjectMapper
import SwiftUI

enum SystemConfigStoreError: Error {
    case invalidAppID
    case invalidConfiguration
    case serializationFailed
}

/// 通过 ObjectMapper 序列化，按邀请码保存登录前的系统配置。
@MainActor
final class SystemConfigStore {
    static let shared = SystemConfigStore()

    private init() {}

    func save(_ configuration: SystemConfigRecord, appID: String, apiHost: URL) throws {
        guard configuration.isValidForLogin else {
            throw SystemConfigStoreError.invalidConfiguration
        }
        let appID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appID.isEmpty else { throw SystemConfigStoreError.invalidAppID }
        let record = SystemConfigCacheRecord(
            appID: appID,
            apiHost: apiHost,
            configuration: configuration
        )
        guard let json = Mapper<SystemConfigCacheRecord>().toJSONString(record),
              let restored = Mapper<SystemConfigCacheRecord>().map(JSONString: json),
              restored.appID == appID,
              restored.apiHost == apiHost.absoluteString,
              restored.configuration.isValidForLogin else {
            throw SystemConfigStoreError.serializationFailed
        }
        SystemConfigEntryStorage(key: Self.key(for: appID)).json = json
    }

    /// 缓存可用于页面展示；后续发起登录前仍需判断是否已刷新。
    func load(appID: String, apiHost: URL) -> SystemConfigRecord? {
        guard let record = storedRecord(appID: appID, apiHost: apiHost) else { return nil }
        return record.configuration
    }

    /// 老项目每五分钟刷新系统配置；超时缓存不当作登录就绪状态。
    func loadFresh(appID: String, apiHost: URL) -> SystemConfigRecord? {
        guard let record = storedRecord(appID: appID, apiHost: apiHost) else {
            return nil
        }
        let age = Date().timeIntervalSince1970 - record.fetchedAt
        guard age >= 0, age < 300 else { return nil }
        return record.configuration
    }

    private func storedRecord(appID: String, apiHost: URL) -> SystemConfigCacheRecord? {
        let appID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appID.isEmpty else { return nil }
        let json = SystemConfigEntryStorage(key: Self.key(for: appID)).json
        guard !json.isEmpty,
              let record = Mapper<SystemConfigCacheRecord>().map(JSONString: json),
              record.appID == appID,
              record.apiHost == apiHost.absoluteString,
              record.configuration.isValidForLogin else {
            return nil
        }
        return record
    }

    private static func key(for appID: String) -> String {
        let digest = SHA256.hash(data: Data(appID.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return systemConfigAppStorageKeyPrefix + digest
    }
}

@MainActor
private struct SystemConfigEntryStorage {
    @AppStorage var json: String

    init(key: String) {
        _json = AppStorage(wrappedValue: "", key)
    }
}
