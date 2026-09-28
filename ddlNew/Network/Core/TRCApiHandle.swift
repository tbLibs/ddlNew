//
//  TRCApiHandle.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation
import Moya

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
