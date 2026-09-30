//
//  ContactsClientError.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation

/// 空数组代表没有好友，读取失败不能伪装成空数组覆盖已有快照。
nonisolated enum ContactsClientError: LocalizedError {
    case cacheReadFailed

    var errorDescription: String? { "SDK 好友数据库读取失败" }
}
