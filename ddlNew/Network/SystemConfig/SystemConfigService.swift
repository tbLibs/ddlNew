// 已停用：tenantCode 和功能规则均使用本地固定值。原接口实现仅留作历史参考，不参与编译。
/*
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
    /// 解密后的响应缺少业务验签所需的 tenantCode。
    case invalidTenantCode
    /// 请求期间邀请码或 HTTP 节点已切换，不能应用这次响应。
    case staleNavigation
}

/// 保留原接口与解密协议，只提取 tenantCode；不映射、不缓存任何远程功能配置。
@MainActor
final class SystemConfigService {
    static let shared = SystemConfigService()

    private init() {}

    func fetchTenantCredentials(for plan: OSSConnectionPlan) async throws -> TenantCredentials {
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
        
        let credentials: TenantCredentials
        do {
            credentials = try TenantCredentials(dictionary: dictionary)
        } catch {
            throw SystemConfigServiceError.invalidTenantCode
        }

        // await 后重新检查任务与导航，避免切换邀请码时应用过期租户参数。
        try _Concurrency.Task<Never, Never>.checkCancellation()
        guard let current = OSSConnectionBootstrap.shared.current,
              current.lastLiceseId == plan.lastLiceseId,
              current.apiHost == plan.apiHost else {
            throw SystemConfigServiceError.staleNavigation
        }
        return credentials
    }

}

*/
