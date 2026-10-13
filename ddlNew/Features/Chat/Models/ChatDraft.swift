//
//  ChatDraft.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

struct ChatDraft: Equatable, Sendable {
    var text: String = ""
    var referenceID: String = ""
    var mentions: [ChatMentionSegment] = []
}
