//
//  HTTPAuthAvailabilityProbe.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation
import Moya
import RxMoya
import RxSwift

enum HTTPAuthProbeError: Error {
    case businessFailure(code: Int)
    case invalidResponse
    case staleNavigation
}

/// 仅探测 HTTP 获取加密密钥接口；不能据此推断登录 POST 或 IM Socket 已可用。
@MainActor
final class HTTPAuthAvailabilityProbe {
    static let shared = HTTPAuthAvailabilityProbe()

    private init() {}

    func verifyKeyEndpoint(plan: OSSConnectionPlan, configuration: SystemConfigRecord) async throws {
        try _Concurrency.Task<Never, Never>.checkCancellation()
        let timestamp = Int64(Date().timeIntervalSince1970)
        let signature = try SystemConfigCrypto.authenticationSignature(
            tenantCode: configuration.tenantCode,
            timestamp: timestamp
        )
        let headers = BusinessRequestHeaders.make(
            timestamp: timestamp,
            signature: signature,
            appID: plan.appID
        )
        let response = try await ApiRequest.rx
            .request(.generateEncryptKey(baseURL: plan.apiHost, headers: headers))
            .filterSuccessfulStatusCodes()
            .value
        try _Concurrency.Task<Never, Never>.checkCancellation()

        let status = try response.mapObject(BusinessResponseStatus.self)
        guard status.code == 10000 else {
            throw HTTPAuthProbeError.businessFailure(code: status.code)
        }
        guard let root = try response.mapJSON() as? [String: Any],
              let keyPayload = root["data"] as? String,
              !keyPayload.isEmpty else {
            throw HTTPAuthProbeError.invalidResponse
        }
        // 只确认服务端按 HTTP 返回了密钥数据，不持有、不打印密钥。
        guard let current = OSSConnectionBootstrap.shared.current,
              current.appID == plan.appID,
              current.apiHost == plan.apiHost else {
            throw HTTPAuthProbeError.staleNavigation
        }
    }
}
