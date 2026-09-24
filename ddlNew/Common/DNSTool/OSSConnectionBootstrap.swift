//
//  OSSConnectionBootstrap.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import CryptoKit
import Foundation
import SwiftUI

/// 等待后续 ECDH 探测的 TCP 候选节点。
nonisolated struct OSSIMTCPNode: Equatable, Sendable {
    let host: String
    let port: UInt16
}

/// 对应旧项目先选 HTTP Host、再用 tcpArr 探测的连接准备结果。
nonisolated struct OSSConnectionPlan: Sendable {
    /// 所属邀请码，防止连接状态串用其他企业的节点。
    let appID: String
    /// 旧项目的 apiHost。
    let apiHost: URL
    /// 旧项目的 getFileHost，与 API Host 相同。
    let getFileHost: URL
    /// 旧项目的 uploadfileHost，在 API Host 后追加 /oss。
    let uploadFileHost: URL
    /// 尚未执行 ECDH 连通探测的 TCP 节点。
    let tcpCandidates: [OSSIMTCPNode]
}

/// 导航缓存或节点不满足下一阶段连接准备要求。
enum OSSConnectionBootstrapError: Error {
    /// 没有当前邀请码的导航缓存。
    case missingNavigation
    /// 恢复缓存时服务端 TTL 已过期。
    case expiredNavigation
    /// 旧结构的 httpArr 为空。
    case missingHTTPNode
    /// 首个 HTTP 地址不能作为 HTTPS API Host。
    case invalidHTTPNode
    /// 旧结构的 tcpArr 没有有效地址和端口。
    case missingTCPNodes
}

/// 只完成旧项目的 HTTP Host 选用和 TCP 候选准备；不把普通 TCP 连通当作 ECDH 成功。
@MainActor
final class OSSConnectionBootstrap {
    static let shared = OSSConnectionBootstrap()

    /// 当前邀请码的待连接方案；切换邀请码时清空，缓存仍按邀请码保留。
    private(set) var current: OSSConnectionPlan?

    private init() {}

    /// 新导航成功后立即使用；从磁盘恢复时默认要求服务端缓存尚未过期。
    @discardableResult
    func prepare(appID: String, requireFresh: Bool = true) throws -> OSSConnectionPlan {
        let appID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ssoInfo = try OSSNavigationStore.shared.loadSSOInfo(appID: appID) else {
            throw OSSConnectionBootstrapError.missingNavigation
        }
        let navigation = try ssoInfo.snapshot(for: appID)
        guard !requireFresh || !navigation.isExpired else {
            throw OSSConnectionBootstrapError.expiredNavigation
        }

        // 旧项目此路径直接选用 httpArr.firstObject，不先发起 HTTP 探测。
        guard let firstHTTP = ssoInfo.ossRacingModel.httpArr.first else {
            throw OSSConnectionBootstrapError.missingHTTPNode
        }
        guard let apiHost = Self.httpsURL(from: firstHTTP.ip) else {
            throw OSSConnectionBootstrapError.invalidHTTPNode
        }
        let tcpCandidates = ssoInfo.ossRacingModel.tcpArr.compactMap { item -> OSSIMTCPNode? in
            let host = item.ip.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !host.isEmpty, !host.contains("/"), !host.contains(" "),
                  let port = UInt16(exactly: item.sort), port > 0 else {
                return nil
            }
            return OSSIMTCPNode(host: host, port: port)
        }
        guard !tcpCandidates.isEmpty else {
            throw OSSConnectionBootstrapError.missingTCPNodes
        }

        let plan = OSSConnectionPlan(
            appID: appID,
            apiHost: apiHost,
            getFileHost: apiHost,
            uploadFileHost: apiHost.appending(path: "oss"),
            tcpCandidates: tcpCandidates
        )
        // 对齐旧项目的 CONNECT_LOCAL_CACHE：按邀请码保留已选 API Host。
        OSSSelectedHTTPHostStorage(key: Self.storageKey(for: appID)).value = apiHost.absoluteString
        current = plan
        return plan
    }

    func clearCurrent() {
        current = nil
    }

    /// 供后续重连链路读取上次选用的 HTTP Host，不代表该地址仍然可达。
    func cachedHTTPHost(appID: String) -> URL? {
        let appID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appID.isEmpty else { return nil }
        let value = OSSSelectedHTTPHostStorage(key: Self.storageKey(for: appID)).value
        return Self.httpsURL(from: value)
    }

    private static func httpsURL(from address: String) -> URL? {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let raw = value.contains("://") ? value : "https://\(value)"
        guard var components = URLComponents(string: raw),
              components.scheme == "http" || components.scheme == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/" else {
            return nil
        }
        // 旧项目把 http:// 统一升级为 https://。
        components.scheme = "https"
        components.path = ""
        return components.url
    }

    private static func storageKey(for appID: String) -> String {
        let digest = SHA256.hash(data: Data(appID.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return ossSelectedHTTPHostAppStorageKeyPrefix + digest
    }
}

@MainActor
private struct OSSSelectedHTTPHostStorage {
    @AppStorage var value: String

    init(key: String) {
        _value = AppStorage(wrappedValue: "", key)
    }
}
