//
//  NetworkPath.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation

/// 业务服务端的接口路径，DNS 服务地址仍由各自的 Moya 目标管理。
enum NetworkPath {
    /// 获取未登录系统配置。
    static let systemConfig = "/biz/system/v2/getSystemConfig"
    /// 获取本次密码登录使用的加密密钥，不提交账号信息。
    static let generateEncryptKey = "/auth/account/v2/generateEncryptKey"
    /// 老项目对获取密钥接口验签时使用去掉 /auth/ 的 URI。
    static let generateEncryptKeySignatureURI = "account/v2/generateEncryptKey"
}
