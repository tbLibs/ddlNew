//
//  APIClient.swift
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//


import Foundation
import RxSwift
import Moya
import Alamofire

/// DNS/DoH 请求使用系统默认的证书校验。
var ApiRequest = MoyaProvider<ApiType>(plugins: [TRCApiHandle()])

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

/// 为项目网络请求统一设置超时并预留发送、响应处理入口。
class TRCApiHandle: PluginType {
    func willSend(_ request: any RequestType, target: any TargetType) {
        
    }
    
    func didReceive(_ result: Result<Response, MoyaError>, target: any TargetType) {
        // 获取请求状态码
        switch result {
        case .success:
            break
        case .failure:
            break
        }
    }
    
    func prepare(_ request: URLRequest, target: any TargetType) -> URLRequest {
        var mrequest = request
        // 系统配置接口沿用旧项目的 10 秒请求超时，DNS 查询保持 5 秒。
        if let target = target as? ApiType {
            switch target {
            case .systemConfig, .generateEncryptKey:
                mrequest.timeoutInterval = 10
            default:
                mrequest.timeoutInterval = 5
            }
        }
        return mrequest
    }
    
    func process(_ result: Result<Response, MoyaError>, target: any TargetType) -> Result<Response, MoyaError> {
        result
    }
    
}

/// 保留旧 Rx 调用的订阅容器；async/await 的 DNS 请求不依赖它。
class DisposeBagHelper {
    public static let share = DisposeBagHelper()
    public required init() {}
    public let disposeBag = DisposeBag()
}

// MARK: - - common模块的请求
/// 旧回调式请求入口的类型和订阅容器。
class DDLApiRequest {
    typealias RequestSuccessCallBack<T> = (_ response: T) -> Void
    typealias RequestFailCallBack = (_ response: Error?) -> Void
    static let share = DDLApiRequest()
    required init() { }
    let disposeBag = DisposeBagHelper.share.disposeBag
}
