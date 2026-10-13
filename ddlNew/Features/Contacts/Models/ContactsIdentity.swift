//
//  ContactsIdentity.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 用户、俱乐部与运行轮次共同标识通讯录请求归属。
nonisolated struct ContactsIdentity: Equatable, Sendable {
    let userUID: String
    let license: String
    let generation: UUID
    var persistenceKey: String { "\(license.utf8.count):\(license)\(userUID)" }
}
