//
//  SDKContactsDelegate.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation
import NoaChatCore

/// 将 SDK 用户代理转成值类型事件；代理对象由客户端持有并随账号释放。
nonisolated final class SDKContactsDelegate: NSObject, NoaToolUserDelegate {
    private let onChange: @Sendable (ContactsChange) -> Void

    init(onChange: @escaping @Sendable (ContactsChange) -> Void) { self.onChange = onChange }

    func cimToolUserConnectSuccess() { onChange(.syncStarted) }
    func imSdkUserContactsSyncFinish() { onChange(.syncFinished) }
    func imSdkUserContactsSyncFailed(_ errorMsg: String?) { onChange(.syncFailed(errorMsg ?? "好友同步失败")) }
    func imSdkUserFriendAdd(_ friendAddModel: LingIMFriendModel) { onChange(.changed) }
    func imSdkUserFriendDelete(_ friendDeleteModel: LingIMFriendModel) { onChange(.changed) }
    func cimToolUserFriendChange(_ message: LingIMFriendModel) { onChange(.changed) }
    func cimToolUserFriendConfirm(_ message: IMServerMessage) { onChange(.changed) }
    func cimToolUserFriendDelete(_ message: FriendDelMessage) { onChange(.changed) }
    func cimToolUserFriendLineStatus(_ message: IMServerMessage) { onChange(.changed) }
    func imSdkUserFriendGroupChange() { onChange(.changed) }
    func cimToolUserFriendRemarkChange(_ message: SynchroMessage) {
        onChange(.remarkChanged(message.sessionId))
    }
}
