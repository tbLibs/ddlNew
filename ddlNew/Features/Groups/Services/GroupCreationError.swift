//
//  GroupCreationError.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 服务端已返回群ID后缓存失败属于待同步，不能再提示重新建群。
nonisolated enum GroupCreationError: LocalizedError {
    case cachePending(GroupRecord)
    var errorDescription: String? { "群已创建，本机缓存待同步。请刷新群列表确认，不要重复创建。" }
}
