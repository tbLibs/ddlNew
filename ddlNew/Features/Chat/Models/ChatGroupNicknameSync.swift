//
//  ChatGroupNicknameSync.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import Foundation

struct ChatGroupNicknameSync: Sendable {
    let groupID: String
    let senderID: String
    let nickname: String
    /// Socket线程立即复制协议字符串，不把可变Protobuf跨actor传递。
    nonisolated init(groupID: String, senderID: String, nickname: String) { self.groupID = groupID; self.senderID = senderID; self.nickname = nickname }
}
