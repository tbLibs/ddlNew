//
//  ContactsRoute.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

/// 路由只携带稳定UID，页面出现后读取当前资料与关系。
nonisolated struct ContactsRoute: Hashable, Identifiable, Sendable {
    let contactID: String
    let sourceGroupID: String?
    let applicationID: String?
    /// 群成员资料携带来源群，直接好友入口保持nil。
    init(contactID: String, sourceGroupID: String? = nil, applicationID: String? = nil) { self.contactID = contactID; self.sourceGroupID = sourceGroupID; self.applicationID = applicationID }
    var id: String { contactID }
}
