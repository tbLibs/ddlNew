//
//  OSSNavigationStore.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import CryptoKit
import Foundation
import ObjectMapper
import SwiftUI

/// 按邀请码保存的导航状态，后续 HTTP/TCP 连接从这里读取节点和服务端配置。
nonisolated struct OSSNavigationSnapshot: Sendable {
    /// 导航所属的邀请码（旧协议的 liceseId）。
    let appID: String
    /// 获胜的 DNS 来源。
    let source: DNSHostSource
    /// 返回有效导航数据的 OSS 节点。
    let ossNode: DNSResolvedHost
    /// 保存时刻，供后续按服务端 TTL 决定是否重新导航。
    let savedAt: Date
    /// 服务端返回的完整导航响应体。
    let body: IMServerListResponseBody
    /// 可用的 TCP 节点；同一节点也可能出现在 HTTP 列表中。
    let tcpEndpoints: [IMServerEndpoint]
    /// 可用的 HTTP 节点。
    let httpEndpoints: [IMServerEndpoint]

    /// 国内、海外兜底导航地址；空列表更新不会覆盖之前的非空地址。
    var fallbackEndpoints: FallbackEndpoints { body.fallbackEndpoints }
    /// 服务端下发的配置；未下发时为 nil，不擅自套用协议注释中的默认值。
    var configuration: NavigationConfig? {
        guard body.hasMeta, body.meta.hasConfig else { return nil }
        return body.meta.config
    }
    /// 服务端返回的缓存有效期，单位为秒。
    var cacheTTL: Int64 { body.cacheTtl }
    /// 是否已超过服务端明确给出的缓存有效期；不删除持久化数据。
    var isExpired: Bool {
        guard cacheTTL > 0 else { return true }
        return Date().timeIntervalSince(savedAt) >= Double(cacheTTL)
    }
}

/// 缓存格式不受支持或数据损坏时，阻止后续连接使用该导航状态。
enum OSSNavigationStoreError: Error {
    case invalidAppID
    case invalidStoredNavigation
}

/// 导航状态的统一入口。AppStorage 不保存 OSS Auth 签名密钥，按邀请码隔离导航响应。
@MainActor
final class OSSNavigationStore {
    static let shared = OSSNavigationStore()

    private init() {}

    /// 保存竞速首胜结果，并保留旧项目的“非空兜底地址才覆盖”规则。
    @discardableResult
    func save(_ winner: OSSRaceWinner, appID: String) throws -> OSSNavigationSnapshot {
        let appID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appID.isEmpty else { throw OSSNavigationStoreError.invalidAppID }

        let previousRecord = try? storedRecord(for: appID)
        var body = winner.navigation.body
        if let previous = try? previousRecord?.snapshot(for: appID) {
            var fallback = body.fallbackEndpoints
            let oldFallback = previous.fallbackEndpoints
            if fallback.domestic.isEmpty { fallback.domestic = oldFallback.domestic }
            if fallback.overseas.isEmpty { fallback.overseas = oldFallback.overseas }
            if !fallback.domestic.isEmpty || !fallback.overseas.isEmpty {
                body.fallbackEndpoints = fallback
            }
        }

        let savedAt = Date()
        let record = try OSSNavigationRecord(
            appID: appID,
            source: winner.source,
            ossNode: winner.node,
            savedAt: savedAt,
            body: body,
            previous: previousRecord
        )
        let mapper = Mapper<OSSNavigationRecord>()
        guard let json = mapper.toJSONString(record),
              let restored = mapper.map(JSONString: json),
              let snapshot = try? restored.snapshot(for: appID) else {
            throw OSSNavigationStoreError.invalidStoredNavigation
        }
        OSSNavigationEntryStorage(key: key(for: appID)).json = json
        return snapshot
    }

    /// 读取指定邀请码的导航状态。调用方应检查 isExpired 后决定是否重新竞速。
    func load(appID: String) throws -> OSSNavigationSnapshot? {
        let appID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appID.isEmpty else { throw OSSNavigationStoreError.invalidAppID }
        return try storedRecord(for: appID)?.snapshot(for: appID)
    }

    /// 读取与旧项目 NoaSsoInfoModel 对齐的 SSO 结构，包含 httpArr/tcpArr。
    func loadSSOInfo(appID: String) throws -> OSSNavigationRecord? {
        let appID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appID.isEmpty else { throw OSSNavigationStoreError.invalidAppID }
        return try storedRecord(for: appID)
    }

    private func storedRecord(for appID: String) throws -> OSSNavigationRecord? {
        let storage = OSSNavigationEntryStorage(key: key(for: appID))
        let json = storage.json
        guard !json.isEmpty else { return nil }
        if let record = Mapper<OSSNavigationRecord>().map(JSONString: json) {
            _ = try record.snapshot(for: appID)
            return record
        }
        // 同一 AppStorage key 中的旧版数据只在首次读取时迁移，不丢失已保存的节点。
        if let legacy = Mapper<OSSLegacyNavigationRecord>().map(JSONString: json) {
            let snapshot = try legacy.snapshot(for: appID)
            let record = try OSSNavigationRecord(
                appID: appID,
                source: snapshot.source,
                ossNode: snapshot.ossNode,
                savedAt: snapshot.savedAt,
                body: snapshot.body
            )
            let mapper = Mapper<OSSNavigationRecord>()
            guard let migratedJSON = mapper.toJSONString(record),
                  let restored = mapper.map(JSONString: migratedJSON) else {
                throw OSSNavigationStoreError.invalidStoredNavigation
            }
            _ = try restored.snapshot(for: appID)
            storage.json = migratedJSON
            return restored
        }
        throw OSSNavigationStoreError.invalidStoredNavigation
    }

    /// 后续连接优先使用未过期的缓存；过期时返回 nil，由调用方重新发起导航竞速。
    func loadFresh(appID: String) throws -> OSSNavigationSnapshot? {
        guard let snapshot = try load(appID: appID), !snapshot.isExpired else { return nil }
        return snapshot
    }

    private func key(for appID: String) -> String {
        let digest = SHA256.hash(data: Data(appID.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return ossNavigationAppStorageKeyPrefix + digest
    }
}

/// 每个邀请码对应一个 AppStorage 字符串，避免更新某一邀请码时重写其他导航数据。
@MainActor
private struct OSSNavigationEntryStorage {
    @AppStorage var json: String

    init(key: String) {
        _json = AppStorage(wrappedValue: "", key)
    }
}
