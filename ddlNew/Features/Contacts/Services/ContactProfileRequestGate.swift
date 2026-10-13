//
//  ContactProfileRequestGate.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 业务资料与跨端备注刷新共用请求版本，拒绝旧回执写SDK数据库。
@MainActor final class ContactProfileRequestGate {
    static let shared = ContactProfileRequestGate()
    private var versions = ContactRequestVersions()
    /// 同一用户、俱乐部与好友的最后请求拥有写入资格。
    func begin(userUID: String, license: String, friendUID: String) -> UUID { versions.begin(for: key(userUID: userUID, license: license, friendUID: friendUID)) }
    /// 客户端在数据库共用锁内再次核对版本。
    func accepts(_ version: UUID, userUID: String, license: String, friendUID: String) -> Bool { versions.accepts(version, for: key(userUID: userUID, license: license, friendUID: friendUID)) }
    /// 只结束仍为最新的请求，旧回执不能撤销新请求。
    func finish(_ version: UUID, userUID: String, license: String, friendUID: String) { versions.finish(version, for: key(userUID: userUID, license: license, friendUID: friendUID)) }
    /// 退出或准备下一会话时撤销所有旧写入资格。
    func reset() { versions = ContactRequestVersions() }
    /// 长度前缀避免不同UID和邀请码组合产生相同键。
    private func key(userUID: String, license: String, friendUID: String) -> String { "\(license.utf8.count):\(license)\(userUID.utf8.count):\(userUID)\(friendUID)" }
}
