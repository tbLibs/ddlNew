//
//  ChatPermission.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

struct ChatPermission: Equatable, Sendable {
    var canSend = true
    var canUpload = false
    var canUploadFile = false
    var canDelete = false
    var canDeleteBoth = false
    var canRecallOthers = false
    var canRecall = false
    var canEdit = false
    var canPin = false
    var isGroup = false
    var role = 0
    var isActive = true
    var isPrivateChat = false
    var sendInterval: TimeInterval = 0
    var recallWindow: TimeInterval? = nil
    var editWindow: TimeInterval? = nil
    var reason: String = ""
}
