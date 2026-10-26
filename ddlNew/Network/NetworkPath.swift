//
//  NetworkPath.swift
//  ddlNew
//
//  Created by taobo on 2026/9/24.
//

import Foundation

/// 业务服务端的接口路径，DNS 服务地址仍由各自的 Moya 目标管理。
enum NetworkPath {
    /// 老端 Minio 上传先获取临时加密公钥，随后提交单文件或五十 MiB 分片。
    static let chatUploadPublicKey = "/public-key/getKey"
    static let chatUploadFile = "/file/upload"
    static let chatUploadMultipartID = "/file/multi/getId"
    static let chatUploadMultipartPart = "/file/multi/upload"
    static let chatUploadMultipartComplete = "/file/multi/complete"
    /// 旧导航 HTTP 节点择优使用真实 GET 请求测量 RTT。
    static let httpNodePreference = "/zlcpig"
    /// 获取本次密码登录使用的加密密钥，不提交账号信息。
    static let generateEncryptKey = "/auth/account/v2/generateEncryptKey"
    /// 老项目对获取密钥接口验签时使用去掉 /auth/ 的 URI。
    static let generateEncryptKeySignatureURI = "account/v2/generateEncryptKey"
}
