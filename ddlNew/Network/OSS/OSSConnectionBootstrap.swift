//
//  OSSConnectionBootstrap.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Combine
import Foundation
import SwiftUI

/// 等待后续 ECDH 探测的 TCP 候选节点。
nonisolated struct OSSIMTCPNode: Equatable, Sendable {
    let host: String
    let port: UInt16
}

/// 连接准备结果；DNS1 允许没有 HTTP，只携带真实原生 TCP 及可选文件地址。
nonisolated struct OSSConnectionPlan: Sendable {
    /// 所属邀请码，防止连接状态串用其他企业的节点。
    let lastLiceseId: String
    /// 服务端显式下发的 API Host；TCP-only 为 nil。
    let apiHost: URL?
    /// 旧项目的 getFileHost，与 API Host 相同。
    let getFileHost: URL?
    /// 旧项目的 uploadfileHost，在 API Host 后追加 /oss。
    let uploadFileHost: URL?
    /// 尚未执行 ECDH 连通探测的 TCP 节点。
    let tcpCandidates: [OSSIMTCPNode]
    /// 仅当前 DNS1 竞速已验证的节点；不持久化，冷启动缓存不能冒充探测成功。
    var probedTCPNode: OSSIMTCPNode? = nil
}

/// 导航缓存或节点不满足下一阶段连接准备要求。
enum OSSConnectionBootstrapError: Error {
    /// 没有已保存的导航缓存。
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

/// 统一发布连接方案；新 DNS1 与保留的旧导航使用各自验证规则。
@MainActor
final class OSSConnectionBootstrap: ObservableObject {
    static let shared = OSSConnectionBootstrap()

    /// 当前邀请码的待连接方案；切换邀请码时清空，最新导航缓存仍保留。
    @Published private(set) var current: OSSConnectionPlan?
    /// Host 每次准备、切换或清除都推进版本，防止 A→B→A 后旧测速轮次误判为仍有效。
    private(set) var httpHostRevision: UInt64 = 0

    private init() {}

    /// 新导航成功后立即使用；从磁盘恢复时默认要求服务端缓存尚未过期。
    @discardableResult
    func prepare(requireFresh: Bool = true, probedTCPAddress: String? = nil) throws -> OSSConnectionPlan {
        guard let ssoInfo = try OSSNavigationStore.shared.loadSSOInfo() else {
            throw OSSConnectionBootstrapError.missingNavigation
        }
        let navigation = try ssoInfo.snapshot()
        guard !requireFresh || !navigation.isExpired else {
            throw OSSConnectionBootstrapError.expiredNavigation
        }

        // DNS1 不要求 HTTP；先验证版本及载荷，旧连接逻辑保留在下方。
        if dns1NavigationEnabled {
            let payload = try DNS1NodeRaceCoordinator.payload(from: navigation.body)
            let apiHost = payload.http.first
            var plan = OSSConnectionPlan(lastLiceseId: navigation.lastLiceseId, apiHost: apiHost,
                getFileHost: apiHost, uploadFileHost: apiHost?.appending(path: "oss"),
                tcpCandidates: payload.tcp.map { OSSIMTCPNode(host: $0.host, port: $0.port) })
            if let address = probedTCPAddress, let selected = DNS1TCPNode(address),
               payload.tcp.contains(selected) {
                plan.probedTCPNode = OSSIMTCPNode(host: selected.host, port: selected.port)
            }
            OSSSelectedHTTPHostStorage().value = apiHost?.absoluteString ?? ""
            httpHostRevision += 1
            current = plan
            return plan
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
            lastLiceseId: navigation.lastLiceseId,
            apiHost: apiHost,
            getFileHost: apiHost,
            uploadFileHost: apiHost.appending(path: "oss"),
            tcpCandidates: tcpCandidates
        )
        // 对齐旧项目的 CONNECT_LOCAL_CACHE：固定 key 保存最新已选 API Host。
        OSSSelectedHTTPHostStorage().value = apiHost.absoluteString
        httpHostRevision += 1
        current = plan
        return plan
    }

    func clearCurrent() {
        guard current != nil else { return }
        httpHostRevision += 1
        current = nil
    }

    /// SDK 重连时可能切换 HTTP 节点；文件下载和 API 请求须共用更新后的 Host。
    func updateHTTPHost(_ address: String) {
        guard let plan = current else { return }
        let resolved: URL?
        if dns1NavigationEnabled {
            // 旧 SDK 的迟到 HTTP 回调只能选择当前新载荷明确包含的地址。
            guard let snapshot = try? OSSNavigationStore.shared.load(), snapshot.lastLiceseId == plan.lastLiceseId,
                  let payload = try? DNS1NodeRaceCoordinator.payload(from: snapshot.body),
                  let candidate = DNS1Payload.httpURL(address), payload.http.contains(candidate) else { return }
            resolved = candidate
        } else { resolved = Self.httpsURL(from: address) }
        guard let apiHost = resolved else { return }
        guard plan.apiHost != apiHost else { return }
        httpHostRevision += 1
        current = OSSConnectionPlan(
            lastLiceseId: plan.lastLiceseId,
            apiHost: apiHost,
            getFileHost: apiHost,
            uploadFileHost: apiHost.appending(path: "oss"),
            tcpCandidates: plan.tcpCandidates
        )
        OSSSelectedHTTPHostStorage().value = apiHost.absoluteString
    }

    /// 供后续重连链路读取上次选用的 HTTP Host，不代表该地址仍然可达。
    func cachedHTTPHost() -> URL? {
        if dns1NavigationEnabled { return DNS1Payload.httpURL(OSSSelectedHTTPHostStorage().value) }
        return Self.httpsURL(from: OSSSelectedHTTPHostStorage().value)
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
}

@MainActor
private struct OSSSelectedHTTPHostStorage {
    @AppStorage(ossSelectedHTTPHostAppStorageKey) var value = ""
}
