//
//  SystemConfigStore.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation
import ObjectMapper
import SwiftUI

enum SystemConfigStoreError: Error {
    case invalidLastLiceseId
    case invalidConfiguration
    case serializationFailed
}

/// 通过 ObjectMapper 序列化，固定 key 保存最新的登录前系统配置。
@MainActor
final class SystemConfigStore {
    static let shared = SystemConfigStore()

    private init() {}

    func save(_ configuration: SystemConfigRecord, lastLiceseId: String, apiHost: URL) throws {
        guard configuration.isValidForLogin else {
            throw SystemConfigStoreError.invalidConfiguration
        }
        let lastLiceseId = lastLiceseId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lastLiceseId.isEmpty else { throw SystemConfigStoreError.invalidLastLiceseId }
        let record = SystemConfigCacheRecord(
            lastLiceseId: lastLiceseId,
            apiHost: apiHost,
            configuration: configuration
        )
        guard let json = Mapper<SystemConfigCacheRecord>().toJSONString(record),
              let restored = Mapper<SystemConfigCacheRecord>().map(JSONString: json),
              restored.lastLiceseId == lastLiceseId,
              restored.apiHost == apiHost.absoluteString,
              restored.configuration.isValidForLogin else {
            throw SystemConfigStoreError.serializationFailed
        }
        SystemConfigEntryStorage().json = json
    }

    /// 缓存可用于页面展示；后续发起登录前仍需判断是否已刷新。
    func load(apiHost: URL) -> SystemConfigRecord? {
        guard let record = storedRecord(apiHost: apiHost) else { return nil }
        return record.configuration
    }

    /// 老项目每五分钟刷新系统配置；超时缓存不当作登录就绪状态。
    func loadFresh(apiHost: URL) -> SystemConfigRecord? {
        guard let record = storedRecord(apiHost: apiHost) else {
            return nil
        }
        let age = Date().timeIntervalSince1970 - record.fetchedAt
        guard age >= 0, age < 300 else { return nil }
        return record.configuration
    }

    private func storedRecord(apiHost: URL) -> SystemConfigCacheRecord? {
        let json = SystemConfigEntryStorage().json
        guard !json.isEmpty,
              let record = Mapper<SystemConfigCacheRecord>().map(JSONString: json),
              record.apiHost == apiHost.absoluteString,
              record.configuration.isValidForLogin else {
            return nil
        }
        return record
    }
}

/// 固定 key 保存唯一一份配置，读取时只校验 Host 与配置内容，不核对邀请码。
@MainActor
private struct SystemConfigEntryStorage {
    @AppStorage(systemConfigAppStorageKey) var json = ""
}
