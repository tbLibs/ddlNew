//
//  ChatRoute.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

struct ChatRoute: Identifiable, Hashable, Sendable {
    let id: String
    let kind: ConversationKind
    let title: String
    let avatarURL: String
    let targetMessageID: String?
    let sourceGroupID: String?

    /// 稳定会话身份与可选搜索定位目标，原入口无需传定位参数。
    init(id: String, kind: ConversationKind, title: String, avatarURL: String, targetMessageID: String? = nil, sourceGroupID: String? = nil) {
        self.id = id; self.kind = kind; self.title = title; self.avatarURL = avatarURL
        self.targetMessageID = targetMessageID; self.sourceGroupID = sourceGroupID
    }
}
