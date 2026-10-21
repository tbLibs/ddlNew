//
//  SystemConfigService.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation
import ObjectMapper

/// 系统配置请求已返回后，在业务响应解析与导航一致性校验中产生的错误。
enum SystemConfigServiceError: Error {
    /// 响应体不是预期的 JSON 对象。
    case invalidResponse
    /// HTTP 请求成功，但服务端返回的业务码不是成功码。
    case businessFailure(code: Int, message: String)
    /// 响应中缺少 data，或 data 为 null。
    case missingData
    /// 解密后的配置无法映射，或缺少登录所需的有效字段。
    case invalidConfiguration
    /// 请求期间邀请码或 HTTP 节点已切换，不能保存这次响应。
    case staleNavigation
}

/// 正式 ECDH 完成后复用旧 SDK 的配置请求通道，再由协调器应用登录策略。
@MainActor
final class SystemConfigService {
    static let shared = SystemConfigService()
    private let client = SDKSessionMaintenanceClient()
    private var requestGeneration = UUID()

    /// 连接协调器统一拥有启动配置，避免页面重复创建请求所有者。
    private init() {}

    /// SDK 在已配置 Socket 时走 TCP，HTTP 不可达不能阻断已经成功的 ECDH 链路。
    func fetchAndCache(for plan: OSSConnectionPlan) async throws -> SystemConfigRecord {
        try _Concurrency.Task<Never, Never>.checkCancellation()
        let run = UUID()
        requestGeneration = run
        // 与旧项目初始化及现有会话维护共用签名、解密和有界 SDK 等待。
        let json = try await client.configuration(host: plan.apiHost, loggedIn: false)
        try _Concurrency.Task<Never, Never>.checkCancellation()
        guard requestGeneration == run else { throw SystemConfigServiceError.staleNavigation }
        guard let configuration = Mapper<SystemConfigRecord>().map(JSONString: json),
              configuration.isValidForLogin else {
            throw SystemConfigServiceError.invalidConfiguration
        }

        // await 后重新检查任务与导航，避免切换邀请码时保存过期响应。
        try _Concurrency.Task<Never, Never>.checkCancellation()
        guard let current = OSSConnectionBootstrap.shared.current,
              current.lastLiceseId == plan.lastLiceseId,
              current.apiHost == plan.apiHost else {
            throw SystemConfigServiceError.staleNavigation
        }
        try SystemConfigStore.shared.save(
            configuration,
            lastLiceseId: plan.lastLiceseId,
            apiHost: plan.apiHost
        )
        CallConfigurationStore.shared.update(json: json, tenantID: plan.lastLiceseId)
        return configuration
    }

}
