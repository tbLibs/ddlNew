//
//  ChatContext.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 身份包含租户和登录轮次，同UID重登也不能复用旧请求。
struct ChatContext: Equatable, Sendable {
    let userUID: String
    let tenantID: String
    let sessionID: UUID
    let route: ChatRoute
}
