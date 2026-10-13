//
//  SDKContactsBusinessDelegate.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore

/// 业务观察只负责申请/分组事件，不重复拥有好友缓存同步。
nonisolated final class SDKContactsBusinessDelegate: NSObject, NoaToolUserDelegate {
    let change: @Sendable () -> Void
    let removed: @Sendable (String) -> Void
    /// 代理将事件交回主线程Store合并请求。
    init(change: @escaping @Sendable () -> Void, removed: @escaping @Sendable (String) -> Void) { self.change = change; self.removed = removed }
    /// 对方新申请后刷新第一页。
    func cimToolUserFriendInvite(_ message: FriendInviteMessage) { change() }
    /// 跨端接受后重新确认申请状态。
    func cimToolUserFriendConfirm(_ message: IMServerMessage) { change() }
    /// 好友删除使所有旧资料回执失去写入资格，防止重新加回SDK库。
    func imSdkUserFriendDelete(_ friend: LingIMFriendModel) { removed(friend.friendUserUID ?? "") }
    /// 分组变化后回读SDK数据。
    func imSdkUserFriendGroupChange() { change() }
    /// 完成首次同步后分组数据库才可完整回读。
    func imSdkUserContactsSyncFinish() { change() }
}
