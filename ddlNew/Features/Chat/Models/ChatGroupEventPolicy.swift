//
//  ChatGroupEventPolicy.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import Foundation

enum ChatGroupEventPolicy {
    /// 真实协议221个人禁言、204踢人和515历史删除分别产生权限与正文失效事件。
    nonisolated static func events(kind: Int, groupID: String, conversationID: String, removedIDs: [String] = [], deletesHistory: Bool = false) -> [ChatEvent] {
        guard !groupID.isEmpty, groupID == conversationID else { return [] }
        switch kind {
        case 221: return [.permissionsChanged]
        case 204: return [.permissionsChanged] + (deletesHistory && !removedIDs.isEmpty ? [.memberHistoryDeleted(removedIDs)] : [])
        case 515: return removedIDs.isEmpty ? [] : [.memberHistoryDeleted(removedIDs)]
        default: return []
        }
    }
}
