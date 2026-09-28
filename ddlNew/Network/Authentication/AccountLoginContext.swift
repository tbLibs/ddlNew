//
//  AccountLoginContext.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

/// 记录真实连接轮次，不使用本地缓存存在与否判断登录是否可发起。
nonisolated struct AccountLoginContext: Equatable {
    let connectionID: UUID
    let loginMethod: String
    let captchaChannel: Int
}
