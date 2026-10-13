//
//  SDKChatMessageMapper.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore

/// ObjC可变消息在代理线程转换成Swift值，避免跨线程持有SDK对象。
enum SDKChatMessageMapper {
    /// 用当前UID判断多端自己的消息方向，单聊收件人为自己时归发送者会话。
    nonisolated static func record(_ model: NoaIMChatMessageModel, userUID: String) -> ChatMessageRecord {
        let type = Int(model.messageType.rawValue)
        let conversation = Int(model.chatType.rawValue) == 1 ? model.toID ?? "" : (model.fromID == userUID ? model.toID ?? "" : model.fromID ?? "")
        var record = ChatMessageRecord(localID: model.msgID ?? "", serverID: model.serviceMsgID ?? "",
            conversationID: conversation, senderID: model.fromID ?? "", senderName: model.fromNickname ?? "",
            avatarURL: model.fromIcon ?? "", type: type,
            text: model.textContent ?? model.showContent ?? model.atContent ?? model.groupNoticeContent ?? model.systemNoticeContent ?? "",
            timestamp: model.sendTime, state: ChatSendState(rawValue: Int(model.messageSendType.rawValue)) ?? .failed,
            failure: failure(Int(model.sendFailureReason.rawValue)), status: ChatMessageStatus(rawValue: model.messageStatus) ?? .normal,
            isRead: model.chatMessageReaded, readCount: model.haveReadCount, totalReadCount: model.totalNeedReadCount,
            referenceID: model.referenceMsgId ?? "")
        record.isEncrypted = model.isEncry; record.snapchat = model.snapchat; record.isCompatible = model.currentVersionMessageOK
        switch type {
        case 10:
            var names: [String: String] = [:]
            for dictionary in (model.atUsersInfoList as? [[String: String]] ?? []) { for (uid, name) in dictionary { names[uid] = name } }
            let display = ChatMentionEngine.renderWire(model.atContent ?? model.showContent ?? "", names: names)
            record.text = display.0; record.mentions = display.1
        case 1: record.resource = model.imgName ?? ""; record.thumbnail = model.thumbnailImg ?? ""; record.size = Int64(model.imgSize)
        case 2: record.resource = model.videoName ?? ""; record.thumbnail = model.videoCover ?? ""; record.duration = Double(model.videoLength)
        case 4: record.resource = model.voiceName ?? ""; record.duration = Double(model.voiceLength)
        case 5: record.resource = model.filePath ?? ""; record.fileName = model.showFileName ?? model.fileName ?? ""; record.size = Int64(model.fileSize)
        case 6: record.cardUID = model.cardUserId ?? ""; record.text = model.cardNickName ?? model.cardName ?? ""; record.thumbnail = model.cardHeadPicUrl ?? ""
        case 3, 7: record.text = model.geoName ?? ""; record.latitude = model.geoLat ?? ""; record.longitude = model.geoLng ?? ""; record.thumbnail = model.geoImg ?? ""
        case 12: record.resource = model.stickersImg ?? ""; record.thumbnail = model.stickersThumbnailImg ?? ""; record.stickerID = model.stickersId ?? ""; record.isStickerSet = model.isStickersSet; record.size = model.stickersSize
        case 18:
            if let forward = model.forwardMessage {
                record.text = forward.title
                record.nestedMessages = (forward.messageListArray as? [IMChatMessage] ?? []).compactMap { item -> ChatMessageRecord? in
                    guard item.mType.rawValue != 18 else { return nil }
                    let nested = LingIMModelTool.shared().getChatMessageModel(from: item)
                    return SDKChatMessageMapper.record(nested, userUID: userUID)
                }
            }
        case 21: record.text = model.gameStickersResut ?? ""; record.gameType = Int(model.gameSticekersType)
        default: break
        }
        let sdk = NoaIMSDKManager.sharedTool()
        if sdk.myUserID() == userUID, sdk.isUserDatabaseReady() {
            if Int(model.chatType.rawValue) == 1 {
                let member: LingIMGroupMemberModel? = sdk.imSdkCheckGroupMember(with: record.senderID, groupID: record.conversationID)
                if let member {
                    record.senderRole = member.role
                    let remark = member.remarks ?? ""; let groupName = member.nicknameInGroup ?? ""
                    record.senderName = !remark.isEmpty ? remark : !groupName.isEmpty ? groupName : member.userNickname ?? record.senderName
                    record.avatarURL = member.disableStatus == 4 ? "" : member.userAvatar ?? record.avatarURL
                }
            } else {
                let friend: LingIMFriendModel? = sdk.toolCheckMyFriend(with: record.senderID)
                if let friend { record.senderName = friend.showName ?? friend.remarks ?? friend.nickname ?? record.senderName; record.avatarURL = friend.disableStatus == 4 ? "" : friend.avatar ?? record.avatarURL }
            }
        }
        return record
    }

    /// 历史和置顶原文复用SDK真实记录转换，补齐混合数字和布尔字段。
    nonisolated static func historyModel(_ row: [String: Any], context: ChatContext) -> NoaIMChatMessageModel {
        let raw = NoaChatMessageModel()
        raw.msgId = string(row["msgId"]); raw.smsgId = string(row["smsgId"] ?? row["sMsgId"])
        raw.fromUid = string(row["fromUid"]); raw.toUid = string(row["toUid"])
        raw.nick = string(row["nick"]); raw.icon = string(row["icon"])
        raw.referenceMsgId = string(row["referenceMsgId"]); raw.body = row["body"] as? String ?? "{}"
        raw.ctype = CIMChatType(rawValue: UInt(max(0, number(row["ctype"]) ?? (context.route.kind == .group ? 1 : 0)))) ?? CIMChatType(rawValue: 0)!
        raw.mtype = CIMChatMessageType(rawValue: UInt(max(0, number(row["mtype"]) ?? 0))) ?? CIMChatMessageType(rawValue: 0)!
        raw.sendTime = (row["sendTime"] as? NSNumber)?.int64Value ?? Int64(string(row["sendTime"])) ?? 0
        raw.status = number(row["status"]) ?? 1
        raw.isRead = (row["isRead"] as? NSNumber)?.boolValue ?? ["true", "1"].contains(string(row["isRead"]).lowercased())
        raw.isAck = (row["isAck"] as? NSNumber)?.boolValue ?? false
        raw.isEncry = (row["isEncry"] as? NSNumber)?.boolValue ?? false
        raw.snapchat = number(row["snapchat"]) ?? 0
        raw.haveReadCount = number(row["haveReadCount"]) ?? 0; raw.totalNeedReadCount = number(row["totalNeedReadCount"]) ?? 0
        return raw.getChatMessageFromMessageRecord()
    }
    /// 服务端ID可为字符串或整数，始终保留字符串身份。
    nonisolated private static func string(_ value: Any?) -> String { value as? String ?? (value as? NSNumber)?.stringValue ?? "" }
    /// 小整数类型字段兼容服务端数字字符串。
    nonisolated private static func number(_ value: Any?) -> Int? { (value as? NSNumber)?.intValue ?? Int(string(value)) }

    /// SDK枚举0...7保持旧值，不能直接使用UI枚举rawValue猜失败分类。
    nonisolated static func failure(_ value: Int) -> ChatFailureReason? {
        switch value {
        case 0: return nil
        case 1: return .networkUnavailable
        case 2: return .connectionNotReady
        case 3: return .timeout
        case 4, 12, 13, 14, 15: return .serverRejected
        case 5: return .invalidResponse
        case 8: return .connectionLost
        case 10: return .fileTooLarge
        case 11: return .rateLimited
        default: return .unknown
        }
    }
}
