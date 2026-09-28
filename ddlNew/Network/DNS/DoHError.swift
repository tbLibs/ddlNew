//
//  DoHError.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

/// DoH 请求和载荷解析阶段的错误。
enum DoHError: Error {
    /// 主备地址无法组成有效 URL。
    case invalidURL
    /// 服务返回非成功 DNS 状态。
    case invalidResponse
    /// 响应中没有可用的节点记录。
    case emptyAnswer
    /// TXT 载荷缺少解密配置。
    case missingDecryptionKey
    /// 主备地址的共同请求时限已到。
    case timeout
}
