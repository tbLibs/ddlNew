//
//  APIClient.swift
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//


import Foundation
import RxSwift
import Moya

var ApiRequest = MoyaProvider<ApiType>(plugins: [TRCApiHandle()])

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
        mrequest.timeoutInterval = 5
        return mrequest
    }
    
    func process(_ result: Result<Response, MoyaError>, target: any TargetType) -> Result<Response, MoyaError> {
        result
    }
    
}

class DisposeBagHelper {
    public static let share = DisposeBagHelper()
    public required init() {}
    public let disposeBag = DisposeBag()
}

// MARK: - - common模块的请求
class DDLApiRequest {
    typealias RequestSuccessCallBack<T> = (_ response: T) -> Void
    typealias RequestFailCallBack = (_ response: Error?) -> Void
    static let share = DDLApiRequest()
    required init() { }
    let disposeBag = DisposeBagHelper.share.disposeBag
}
