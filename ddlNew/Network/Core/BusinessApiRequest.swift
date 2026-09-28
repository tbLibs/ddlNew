//
//  BusinessApiRequest.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation
import Moya
import Alamofire

/// 仅业务接口使用导航选出的 Host；旧服务端证书无效且未包含域名，暂时跳过该 Host 的证书和域名校验。
/// 此策略无法验证服务器身份，服务端修复证书后应移除，不能扩展到 DNS/DoH 请求。
enum BusinessApiRequest {
    static func provider(for baseURL: URL) -> MoyaProvider<ApiType> {
        guard let host = baseURL.host else { return ApiRequest }
        let trustManager = ServerTrustManager(evaluators: [
            host: DisabledTrustEvaluator()
        ])
        let session = Session(serverTrustManager: trustManager)
        return MoyaProvider<ApiType>(session: session, plugins: [TRCApiHandle()])
    }
}
