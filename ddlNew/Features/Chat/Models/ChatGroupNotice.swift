//
//  ChatGroupNotice.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

struct ChatGroupNotice: Identifiable, Equatable, Sendable {
    let id: String
    var content: String
    var author: String
    var timestamp: String
    var pinned: Bool
}
