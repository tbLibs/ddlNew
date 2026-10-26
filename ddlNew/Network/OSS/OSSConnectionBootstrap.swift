//
//  OSSConnectionBootstrap.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation
import SwiftUI

/// 等待后续 ECDH 探测的 TCP 候选节点。
nonisolated struct OSSIMTCPNode: Equatable, Sendable {
    let host: String
    let port: UInt16
}

/// DNS1 连接准备结果；HTTP 可为空，不能从 TCP 推算。
nonisolated struct OSSConnectionPlan: Sendable {
    /// 所属邀请码，防止连接状态串用其他企业的节点。
    let lastLiceseId: String
    /// 旧项目的 apiHost。
    let apiHost: URL?
    /// 旧项目的 getFileHost，与 API Host 相同。
    let getFileHost: URL?
    /// 旧项目的 uploadfileHost，在 API Host 后追加 /oss。
    let uploadFileHost: URL?
    /// 尚未执行 ECDH 连通探测的 TCP 节点。
    let tcpCandidates: [OSSIMTCPNode]
    /// 仅本轮 DNS1 已完成 ECDH 的节点，不持久化。
    var probedTCPNode: OSSIMTCPNode? = nil
}

/// 导航缓存或节点不满足下一阶段连接准备要求。
enum OSSConnectionBootstrapError: Error {
    /// 没有已保存的导航缓存。
    case missingNavigation
    /// 恢复缓存时服务端 TTL 已过期。
    case expiredNavigation

}

/// 将已验证的 DNS1 导航转换为正式连接方案。
@MainActor
final class OSSConnectionBootstrap {
    static let shared = OSSConnectionBootstrap()

    /// 当前邀请码的待连接方案；切换邀请码时清空，最新导航缓存仍保留。
    private(set) var current: OSSConnectionPlan?

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

        let payload = try DNS1NodeRaceCoordinator.payload(from: navigation.body)
        let apiHost = payload.http.first
        var plan = OSSConnectionPlan(lastLiceseId: navigation.lastLiceseId, apiHost: apiHost,
            getFileHost: apiHost, uploadFileHost: apiHost?.appending(path: "oss"),
            tcpCandidates: payload.tcp.map { OSSIMTCPNode(host: $0.host, port: $0.port) })
        if let address = probedTCPAddress, let selected = DNS1TCPNode(address), payload.tcp.contains(selected) {
            plan.probedTCPNode = OSSIMTCPNode(host: selected.host, port: selected.port)
        }
        OSSSelectedHTTPHostStorage().value = apiHost?.absoluteString ?? ""
        current = plan
        return plan
    }

    func clearCurrent() {
        current = nil
    }

    /// 供后续重连链路读取上次选用的 HTTP Host，不代表该地址仍然可达。
    func cachedHTTPHost() -> URL? {
        DNS1Payload.httpURL(OSSSelectedHTTPHostStorage().value)
    }

}

@MainActor
private struct OSSSelectedHTTPHostStorage {
    @AppStorage(ossSelectedHTTPHostAppStorageKey) var value = ""
}
