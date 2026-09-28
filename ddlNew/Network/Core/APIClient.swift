//
//  APIClient.swift
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//


import Foundation
import Moya

/// DNS/DoH 请求使用系统默认的证书校验。
var ApiRequest = MoyaProvider<ApiType>(plugins: [TRCApiHandle()])
