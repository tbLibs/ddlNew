//
//  OSSNavigationStore.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation
import ObjectMapper
import SwiftUI

/// 导航状态包含所属邀请码，后续 HTTP/TCP 连接从这里读取节点和服务端配置。
nonisolated struct OSSNavigationSnapshot: Sendable {
    /// 导航所属的邀请码（旧协议的 liceseId）。
    let lastLiceseId: String
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
    case invalidLastLiceseId
    case invalidStoredNavigation
}

/// 导航状态的统一入口。固定 key 保存最新导航，不保存 OSS Auth 签名密钥。
@MainActor
final class OSSNavigationStore {
    static let shared = OSSNavigationStore()

    private init() {}

    /// 保存竞速首胜结果，并保留旧项目的“非空兜底地址才覆盖”规则。
    @discardableResult
    func save(_ winner: OSSRaceWinner, lastLiceseId: String) throws -> OSSNavigationSnapshot {
        let lastLiceseId = lastLiceseId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lastLiceseId.isEmpty else { throw OSSNavigationStoreError.invalidLastLiceseId }

        let previousRecord = try? storedRecord()
        var body = winner.navigation.body
        if let previous = try? previousRecord?.snapshot() {
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
            lastLiceseId: lastLiceseId,
            source: winner.source,
            ossNode: winner.node,
            savedAt: savedAt,
            body: body,
            previous: previousRecord
        )
        let mapper = Mapper<OSSNavigationRecord>()
        guard let json = mapper.toJSONString(record),
              let restored = mapper.map(JSONString: json),
              let snapshot = try? restored.snapshot() else {
            throw OSSNavigationStoreError.invalidStoredNavigation
        }
        OSSNavigationEntryStorage().json = json
        return snapshot
    }

    /// 直接读取唯一的导航缓存。调用方应检查 isExpired 后决定是否重新竞速。
    func load() throws -> OSSNavigationSnapshot? {
        return try storedRecord()?.snapshot()
    }

    /// 读取与旧项目 NoaSsoInfoModel 对齐的 SSO 结构，包含 httpArr/tcpArr。
    func loadSSOInfo() throws -> OSSNavigationRecord? {
        return try storedRecord()
    }

    /// 对齐旧项目 lastLiceseId：完整入口准备成功后才更新，不由单次 OSS 成功覆盖。
    func markLastUsableEntry(lastLiceseId: String) throws {
        let lastLiceseId = lastLiceseId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lastLiceseId.isEmpty else { throw OSSNavigationStoreError.invalidLastLiceseId }
        guard var record = try storedRecord() else {
            throw OSSNavigationStoreError.invalidStoredNavigation
        }
        record.lastLiceseId = lastLiceseId
        record.lastIPDomainPortStr = record.ipDomainPortStr
        let mapper = Mapper<OSSNavigationRecord>()
        guard let json = mapper.toJSONString(record),
              let restored = mapper.map(JSONString: json),
              restored.lastLiceseId == lastLiceseId else {
            throw OSSNavigationStoreError.invalidStoredNavigation
        }
        _ = try restored.snapshot()
        // 启动入口和导航保存在同一份 JSON 中，不再单独保存 lastLiceseId。
        OSSNavigationEntryStorage().json = json
    }

    /// 主动更换俱乐部只清除启动入口，保留最新导航及已保存的配置。
    func clearLastUsableEntry() throws {
        let storage = OSSNavigationEntryStorage()
        guard !storage.json.isEmpty else { return }
        let mapper = Mapper<OSSNavigationRecord>()
        guard var record = mapper.map(JSONString: storage.json) else {
            throw OSSNavigationStoreError.invalidStoredNavigation
        }
        record.lastLiceseId = ""
        guard let json = mapper.toJSONString(record),
              let restored = mapper.map(JSONString: json),
              restored.lastLiceseId.isEmpty else {
            throw OSSNavigationStoreError.invalidStoredNavigation
        }
        // 只清空用于启动恢复的字段，节点、当前 liceseId 和其他导航数据保持不变。
        storage.json = json
    }

    /// 本地入口只用于决定页面，不表示缓存未过期、账号已登录或 IM 已连接。
    func lastUsableLiceseId() -> String? {
        // 页面恢复只读取入口字段，节点有效性留给连接准备流程检查。
        guard let record = Mapper<OSSNavigationRecord>().map(JSONString: OSSNavigationEntryStorage().json) else {
            return nil
        }
        let lastLiceseId = record.lastLiceseId
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return lastLiceseId.isEmpty ? nil : lastLiceseId
    }

    private func storedRecord() throws -> OSSNavigationRecord? {
        let storage = OSSNavigationEntryStorage()
        let json = storage.json
        guard !json.isEmpty else { return nil }
        guard let record = Mapper<OSSNavigationRecord>().map(JSONString: json) else {
            throw OSSNavigationStoreError.invalidStoredNavigation
        }
        _ = try record.snapshot()
        return record
    }

    /// 后续连接优先使用未过期的缓存；过期时返回 nil，由调用方重新发起导航竞速。
    func loadFresh() throws -> OSSNavigationSnapshot? {
        guard let snapshot = try load(), !snapshot.isExpired else { return nil }
        return snapshot
    }
}

/// 固定 key 保存唯一一份导航的 ObjectMapper JSON，读取时只校验导航内容。
@MainActor
private struct OSSNavigationEntryStorage {
    @AppStorage(ossNavigationAppStorageKey) var json = ""
}
