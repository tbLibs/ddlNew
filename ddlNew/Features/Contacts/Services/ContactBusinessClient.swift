//
//  ContactBusinessClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 可注入业务客户端，请求和迟到结果均绑定完整身份。
@MainActor protocol ContactBusinessClient: AnyObject {
    /// 所有业务请求携带UID、俱乐部与会话轮次。
    func request(_ operation: ContactBusinessOperation, identity: ContactsIdentity) async throws -> ContactBusinessResponse
    /// 订阅真实申请与分组事件。
    func observe(_ onChange: @escaping @MainActor () -> Void)
    /// 撤销旧客户端请求与代理。
    func reset()
    /// 按当前身份回写SDK申请角标。
    func updateUnreadCount(_ count: Int, identity: ContactsIdentity)
}

extension ContactBusinessClient {
    /// 注入客户端可不写SDK角标，生产客户端实现身份保护后的回写。
    /// 按当前身份回写SDK申请角标。
    func updateUnreadCount(_ count: Int, identity: ContactsIdentity) {}
}
