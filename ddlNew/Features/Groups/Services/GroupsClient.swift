//
//  GroupsClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 群缓存与真实创建接口，便于离线验证会话隔离。
@MainActor protocol GroupsClient: AnyObject {
    /// 注册群同步及增删改观察。
    func observe(_ onChange: @escaping @MainActor () -> Void)
    /// 退出会话时释放群代理和业务等待。
    func reset()
    /// 回读当前用户SDK群库。
    func loadGroups(for userUID: String) async throws -> [GroupRecord]
    /// 通过真实SDK提交建群并返回服务端群身份。
    func createGroup(userUID: String, nickname: String, members: [ContactRecord]) async throws -> GroupRecord
}
