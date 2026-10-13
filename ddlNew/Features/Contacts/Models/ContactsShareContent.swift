//
//  ContactsShareContent.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 分享只携带资料值快照或二维码图片，不传SDK数据库对象。
nonisolated enum ContactsShareContent: Sendable {
    case contact(ContactRecord, sourceGroupID: String?)
    case image(Data)
}
