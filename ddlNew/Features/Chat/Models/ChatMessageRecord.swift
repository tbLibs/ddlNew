//
//  ChatMessageRecord.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

struct ChatMessageRecord: Identifiable, Equatable, Sendable {
    var localID: String
    var serverID: String = ""
    let conversationID: String
    let senderID: String
    var senderName: String
    var avatarURL: String = ""
    var senderRole: Int? = nil
    var type: Int = 0
    var text: String = ""
    var timestamp: Int64
    var state: ChatSendState = .sending
    var failure: ChatFailureReason? = nil
    var status: ChatMessageStatus = .normal
    var isRead: Bool = false
    var readCount: Int = 0
    var totalReadCount: Int = 0
    var referenceID: String = ""
    var mentions: [ChatMentionSegment] = []
    var nestedMessages: [ChatMessageRecord] = []
    var resource: String = ""
    var thumbnail: String = ""
    var fileName: String = ""
    var size: Int64 = 0
    var duration: Double = 0
    var mediaWidth: Double = 0
    var mediaHeight: Double = 0
    var stickerID: String = ""
    var isStickerSet: Bool = false
    var gameType: Int = 0
    var cardUID: String = ""
    var latitude: String = ""
    var longitude: String = ""
    var isEncrypted = false
    var snapchat = 0
    var isCompatible = true
    nonisolated var id: String { localID.isEmpty ? "server:" + serverID : localID }
    nonisolated var isBody: Bool { status == .normal && ![8, 9, 13, 15].contains(type) }
    nonisolated var displayText: String {
        if !isCompatible { return "当前版本暂不支持此消息，请更新后查看" }
        if status == .recalled || type == 8 { return "消息已撤回" }
        switch type {
        case 0, 10, 16, 1000: return text
        case 1: return "[图片]"
        case 2: return "[视频]"
        case 3, 7: return "[位置] " + text
        case 4: return "[语音]"
        case 5: return fileName.isEmpty ? "[文件]" : fileName
        case 6: return "[名片] " + text
        case 12: return "[贴纸]"
        case 21: return gameType == 2 ? "[骰子] " + text : gameType == 1 ? "[石头剪刀布] " + text : "[游戏表情] " + text
        case 18: return "[聊天记录]"
        case 20: return "[通话]"
        default: return "当前版本暂不支持此消息"
        }
    }
}

enum ChatSendState: Int, Sendable { case sending, sent, failed }
enum ChatMessageStatus: Int, Sendable { case deleted = 0, normal = 1, recalled = 2 }
