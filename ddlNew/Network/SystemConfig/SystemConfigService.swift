//
//  SystemConfigService.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation
import Moya
import ObjectMapper
import RxMoya
import RxSwift

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

/// 在未接入 IM SDK 时，使用 OSS 选中的 Host 获取未登录业务配置。
@MainActor
final class SystemConfigService {
    static let shared = SystemConfigService()

    private init() {}

    func fetchAndCache(for plan: OSSConnectionPlan) async throws -> SystemConfigRecord {
        try _Concurrency.Task<Never, Never>.checkCancellation()
        let timestamp = Int64(Date().timeIntervalSince1970)
        let signature = try SystemConfigCrypto.signature(timestamp: timestamp)
        let headers = BusinessRequestHeaders.make(timestamp: timestamp, signature: signature)

        let provider = BusinessApiRequest.provider(for: plan.apiHost)
        let response = try await provider.rx
            .request(.systemConfig(baseURL: plan.apiHost, headers: headers))
            .filterSuccessfulStatusCodes()
            .value
        try _Concurrency.Task<Never, Never>.checkCancellation()

        let envelope = try response.mapObject(BusinessResponseStatus.self)
        guard envelope.code == 10000 else {
            throw SystemConfigServiceError.businessFailure(
                code: envelope.code,
                message: envelope.message
            )
        }
        guard let root = try response.mapJSON() as? [String: Any] else {
            throw SystemConfigServiceError.invalidResponse
        }
        guard let payload = root["data"], !(payload is NSNull) else {
            throw SystemConfigServiceError.missingData
        }
        let dictionary = try SystemConfigCrypto.configurationDictionary(from: payload)
        
        guard let configuration = Mapper<SystemConfigRecord>().map(JSON: dictionary),
              configuration.isValidForLogin else {
            throw SystemConfigServiceError.invalidConfiguration
        }

        // await 后重新检查任务与导航，避免切换邀请码时保存过期响应。
        try _Concurrency.Task<Never, Never>.checkCancellation()
        guard let current = OSSConnectionBootstrap.shared.current,
              current.appID == plan.appID,
              current.apiHost == plan.apiHost else {
            throw SystemConfigServiceError.staleNavigation
        }
        try SystemConfigStore.shared.save(
            configuration,
            appID: plan.appID,
            apiHost: plan.apiHost
        )
        return configuration
    }

}
