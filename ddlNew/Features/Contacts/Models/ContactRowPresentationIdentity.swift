//
//  ContactRowPresentationIdentity.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import Foundation

/// 好友导航行的展示身份独立于资料路由，避免稳定UID保留旧标签快照。
nonisolated struct ContactRowPresentationIdentity: Hashable {
    let contactID: String
    let displayName: String
    let avatarURL: URL?
    let isOnline: Bool
    let isDeleted: Bool
    let roleName: String?

    /// 仅实际展示字段变化时重建行标签，隐藏资料变化不改变身份，资料目标始终使用UID。
    init(contact: ContactRecord, fileHost: URL?, roleName: String?) {
        contactID = contact.id
        displayName = contact.displayName
        avatarURL = contact.avatarURL(relativeTo: fileHost)
        isOnline = contact.isOnline && !contact.isDeleted
        isDeleted = contact.isDeleted
        self.roleName = roleName
    }
}
