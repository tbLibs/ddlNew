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
        case 1: record.mediaWidth = Double(model.imgWidth); record.mediaHeight = Double(model.imgHeight); record.resource = model.imgName ?? ""; record.thumbnail = model.thumbnailImg ?? ""; record.size = Int64(model.imgSize)
        case 2: record.mediaWidth = Double(model.videoCoverW); record.mediaHeight = Double(model.videoCoverH); record.size = Int64(model.videoSize); record.resource = model.videoName ?? ""; record.thumbnail = model.videoCover ?? ""; record.duration = Double(model.videoLength)
        case 4: record.resource = model.voiceName ?? ""; record.duration = Double(model.voiceLength)
        case 5: record.resource = model.filePath ?? ""; record.fileName = model.showFileName ?? model.fileName ?? ""; record.size = Int64(model.fileSize)
        case 6: record.cardUID = model.cardUserId ?? ""; record.text = model.cardNickName ?? model.cardName ?? ""; record.thumbnail = model.cardHeadPicUrl ?? ""
        case 3, 7: record.mediaWidth = Double(model.geoImgWidth); record.mediaHeight = Double(model.geoImgHeight); record.text = model.geoName ?? ""; record.latitude = model.geoLat ?? ""; record.longitude = model.geoLng ?? ""; record.thumbnail = model.geoImg ?? ""
        case 12: record.mediaWidth = Double(model.stickersWidth); record.mediaHeight = Double(model.stickersHeight); record.resource = model.stickersImg ?? ""; record.thumbnail = model.stickersThumbnailImg ?? ""; record.stickerID = model.stickersId ?? ""; record.isStickerSet = model.isStickersSet; record.size = model.stickersSize
        case 18:
            if let forward = model.forwardMessage {
                record.text = forward.title
                record.nestedMessages = (forward.messageListArray as? [IMChatMessage] ?? []).compactMap { item -> ChatMessageRecord? in
                    guard item.mType.rawValue != 18 else { return nil }
                    let nested = LingIMModelTool.shared().getChatMessageModel(from: item)
                    return SDKChatMessageMapper.record(nested, userUID: userUID)
                }
            }
        case 1000: record.text = model.serverMessage.map { systemSummary($0, userUID: userUID) } ?? ""
        case 21: record.text = model.gameStickersResut ?? ""; record.gameType = Int(model.gameSticekersType); record.gameAnimationPlayed = model.isGameAnimationed
        default: break
        }
        let sdk = NoaIMSDKManager.sharedTool()
        if sdk.myUserID() == userUID, sdk.isUserDatabaseReady() {
            if Int(model.chatType.rawValue) == 1 {
                let member: LingIMGroupMemberModel? = sdk.imSdkCheckGroupMember(with: record.senderID, groupID: record.conversationID)
                let friend = sdk.toolCheckMyFriend(with: record.senderID)
                if let member {
                    record.senderRole = member.role
                    let remark = friend.map { $0.remarks ?? "" } ?? member.remarks ?? ""
                    record.senderName = [remark, member.nicknameInGroup ?? "", member.userNickname ?? "", record.senderName, record.senderID].first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? record.senderID
                    // 部分成员缓存尚无头像，不能用空串覆盖消息自带头像；注销状态仍明确清空。
                    if member.disableStatus == 4 || friend?.disableStatus == 4 { record.senderName = "账号已注销"; record.avatarURL = "" }
                    else if let avatar = member.userAvatar, !avatar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { record.avatarURL = avatar }
                }
            } else {
                let friend: LingIMFriendModel? = sdk.toolCheckMyFriend(with: record.senderID)
                if let friend {
                    record.senderName = friend.disableStatus == 4 ? "账号已注销" : [friend.remarks ?? "", friend.nickname ?? "", friend.showName ?? "", record.senderName, record.senderID].first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? record.senderID
                    // 空好友缓存不代表头像已删除，保留消息提供的有效资源。
                    if friend.disableStatus == 4 { record.avatarURL = "" }
                    else if let avatar = friend.avatar, !avatar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { record.avatarURL = avatar }
                }
            }
        }
        return record
    }

    /// 系统事件显示旧项目对应的业务摘要；同步、已读与置顶事件只更新状态不输出正文。
    nonisolated static func systemSummary(_ server: IMServerMessage, userUID: String) -> String {
        let kind = Int(server.sMsgType.rawValue)
        var groupID = ""; var silence = false; var subtype = 0; var informSwitch = 0
        var informUIDs: [String] = []; var actorID = ""; var targetID = ""
        let groupKinds = [200, 203, 204, 205, 206, 207, 208, 210, 211, 213, 215, 216, 217, 218, 219, 221, 222, 230, 231, 237, 238]
        var isGroup = groupKinds.contains(kind)
        switch kind {
        case 200: groupID = server.createGroupMessage?.gid ?? ""; silence = server.createGroupMessage?.isSilence ?? false
        case 203:
            guard let body = server.outGroupMessage else { return "" }
            groupID = body.gid; subtype = Int(body.type); informSwitch = Int(body.informSwitch); informUIDs = body.informUidArray as? [String] ?? []
        case 204:
            guard let body = server.kickGroupMessage else { return "" }
            groupID = body.gid; subtype = Int(body.type); informSwitch = Int(body.informSwitch); informUIDs = body.informUidArray as? [String] ?? []
        case 205: groupID = server.delGroupMessage?.gid ?? ""
        case 206:
            guard let body = server.transferOwnerMessage else { return "" }
            groupID = body.gid; informSwitch = Int(body.informSwitch); informUIDs = body.informUidArray as? [String] ?? []
        case 207, 213, 238: groupID = server.groupStatusMessage?.gid ?? ""
        case 208: groupID = server.noticeGroupMessage?.gid ?? ""
        case 210: groupID = server.nameGroupMessage?.gid ?? ""
        case 211:
            guard let body = server.adminGroupMessage else { return "" }
            groupID = body.gid; informSwitch = Int(body.informSwitch); informUIDs = body.informUidArray as? [String] ?? []
        case 215:
            guard let body = server.inviteConfirmGroupMessage else { return "" }
            groupID = body.gid; subtype = Int(body.type); silence = body.isSilence
            informSwitch = Int(body.informSwitch); informUIDs = body.informUidArray as? [String] ?? []
        case 219: groupID = server.delGroupNotice?.gid ?? ""
        case 221:
            guard let body = server.groupSingleForbidMessage else { return "" }
            groupID = body.gid; actorID = body.fromUid; targetID = body.toUid
        case 230: groupID = server.inviteJoinGroupNoFriendMessage?.gid ?? ""
        case 231: groupID = server.avatarGroupMessage?.gid ?? ""
        case 232:
            guard let body = server.scheduleDeleteMessage else { return "" }
            isGroup = body.chatType.rawValue == 1; groupID = isGroup ? body.peerUid : ""
        case 237: groupID = server.inviteJoinGroupBlackFriendMessage?.gid ?? ""
        default: break
        }
        let sdk = NoaIMSDKManager.sharedTool()
        let group: LingIMGroupModel? = !groupID.isEmpty && sdk.myUserID() == userUID && sdk.isUserDatabaseReady() ? sdk.toolCheckMyGroup(with: groupID) : nil
        guard ChatSystemEventVisibility.shouldDisplay(kind: kind, isGroup: isGroup, userUID: userUID,
            groupInformStatus: group?.groupInformStatus, role: group?.userGroupRole, isSilence: silence,
            subtype: subtype, informSwitch: informSwitch, informUIDs: informUIDs, actorID: actorID, targetID: targetID) else { return "" }
        func name(_ uid: String, _ nick: String, _ group: String = "") -> String {
            if uid == userUID { return "你" }
            let sdk = NoaIMSDKManager.sharedTool()
            var value = nick
            if sdk.myUserID() == userUID, sdk.isUserDatabaseReady() {
                if let friend = sdk.toolCheckMyFriend(with: uid), let display = friend.showName, !display.isEmpty { value = display }
                else if !group.isEmpty {
                    let cached: LingIMGroupMemberModel? = sdk.imSdkCheckGroupMember(with: uid, groupID: group)
                    if let member = cached {
                        let remark = member.remarks ?? ""; let groupName = member.nicknameInGroup ?? ""
                        value = !remark.isEmpty ? remark : !groupName.isEmpty ? groupName : member.userNickname ?? value
                    }
                }
            }
            return value.isEmpty ? "成员" : "“" + value + "”"
        }
        func names(_ values: NSMutableArray, group: String, excluding: String = "") -> String {
            (values as? [NoaChatCore.UserInfo] ?? []).filter { $0.uId != excluding }.map { name($0.uId, $0.uNick, group) }.joined(separator: "、")
        }
        switch Int(server.sMsgType.rawValue) {
        case 105: return "您还不是对方好友，请先添加好友。"
        case 106: return server.friendBlackMessage?.type == 1 ? "已拉黑" : "对方已拒绝接受你的消息"
        case 200:
            guard let body = server.createGroupMessage else { return "" }
            let invited = names(body.inviteUidArray, group: body.gid, excluding: body.uid)
            return name(body.uid, body.nick, body.gid) + (invited.isEmpty ? "创建了群聊" : "邀请了" + invited + "加入群聊")
        case 203:
            guard let body = server.outGroupMessage else { return "" }; return name(body.uid, body.nick, body.gid) + "退出了群聊"
        case 204:
            guard let body = server.kickGroupMessage else { return "" }
            return body.uid == userUID ? "你已被移出群聊" : name(body.operateUid, body.operateNick, body.gid) + "将" + name(body.uid, body.nick, body.gid) + "移出群聊"
        case 205:
            guard let body = server.delGroupMessage else { return "" }; return name(body.uid, body.nick, body.gid) + "解散了该群"
        case 206:
            guard let body = server.transferOwnerMessage else { return "" }; return "群主变更为" + name(body.uid, body.nick, body.gid)
        case 207, 213, 238:
            guard let body = server.groupStatusMessage else { return "" }
            let operation = body.status == 1 ? "开启了" : "关闭了"
            let setting = server.sMsgType.rawValue == 207 ? "全员禁言" : server.sMsgType.rawValue == 213 ? "入群邀请确认" : "新成员可查看历史消息"
            return name(body.uid, body.nick, body.gid) + operation + setting
        case 208:
            guard let body = server.noticeGroupMessage else { return "" }; return name(body.uid, body.nick, body.gid) + "设置了群公告"
        case 210:
            guard let body = server.nameGroupMessage else { return "" }; return name(body.uid, body.nick, body.gid) + "将群名称修改为：" + body.gName
        case 211:
            guard let body = server.adminGroupMessage else { return "" }
            let targets = names(body.adminInfoArray, group: body.gid)
            let target = targets.isEmpty ? name(body.uid, body.nick, body.gid) : targets
            return name(body.operateUid, body.operateNick, body.gid) + (body.type == 1 ? "将" + target + "设为管理员" : "将" + target + "从管理员中移除")
        case 215:
            guard let body = server.inviteConfirmGroupMessage else { return "" }
            if body.type == 5 { return "" }
            let targets = names(body.inviteUidArray, group: body.gid)
            if body.type == 4 { return (targets.isEmpty ? "新成员" : targets) + "通过扫描二维码加入群聊" }
            return name(body.uid, body.nick, body.gid) + "邀请了" + (targets.isEmpty ? "新成员" : targets) + "加入群聊"
        case 216: return "你已不在该群"
        case 217: return "群组已解散"
        case 218: return "该群开启了全员禁言"
        case 219:
            guard let body = server.delGroupNotice else { return "" }; return name(body.uid, body.nick, body.gid) + "删除了群公告"
        case 221:
            guard let body = server.groupSingleForbidMessage else { return "" }
            let target = name(body.toUid, body.toNick, body.gid)
            let actor = name(body.fromUid, body.fromNick, body.gid)
            let duration = body.expireTime > 0 ? "\(body.expireTime)分钟" : ""
            return target + "被" + actor + (body.status == 1 ? "禁言" + duration : "解除禁言")
        case 222: return "你已被禁言"
        case 230:
            guard let body = server.inviteJoinGroupNoFriendMessage else { return "" }; return name(body.operateUid, body.operateNick, body.gid) + "未添加你为好友，无法邀请进入群聊"
        case 231:
            guard let body = server.avatarGroupMessage else { return "" }; return name(body.uid, body.nick, body.gid) + "修改了群头像"
        case 232:
            guard let body = server.scheduleDeleteMessage else { return "" }
            if body.type == 2 { return "已按设置清理到期消息" }
            return name(body.userId, body.userNick) + (body.freq > 0 ? "设置消息在\(body.freq)天后自动删除" : "关闭了消息自动删除")
        case 237:
            guard let body = server.inviteJoinGroupBlackFriendMessage else { return "" }; return name(body.operateUid, body.operateNick, body.gid) + "拒绝加入群聊"
        case 507: return "账号已注销"
        default: return ""
        }
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
