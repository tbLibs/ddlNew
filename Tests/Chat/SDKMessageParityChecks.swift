import Foundation
final class UserInfo: NSObject { var uId = ""; var uNick = ""; init(_ id: String, _ nick: String) { uId = id; uNick = nick } }
final class Body {
    var content = ""
    var fUid = "peer"; var msgId = ""; var sMsgId = ""
    var uid = "B"; var nick = "张三"; var gid = "g"
    var operateUid = "A"; var operateNick = "甲"
    var fromUid = "A"; var fromNick = "甲"; var toUid = "B"; var toNick = "张三"
    var userId = "A"; var userNick = "甲"; var gName = "新的群🌳"
    var peerUid = "g"; var chatType = ServerKind(rawValue: 1)
    var friendUid = "g"; var msgDel = false; var isSilence = false; var informSwitch = 0; var informUidArray = NSMutableArray()
    var status = 1; var type = 1; var expireTime: Int64 = 60; var freq = 7
    var inviteUidArray = NSMutableArray(); var adminInfoArray = NSMutableArray()
}
typealias LingIMGroupMemberModel = CachedPerson
struct CachedPerson { var showName: String? = nil; var remarks: String? = nil; var nicknameInGroup: String? = nil; var userNickname: String? = nil }
struct LingIMGroupModel { var groupInformStatus: Int; var userGroupRole: Int }
struct NoaIMSDKManager {
    static var notificationStatus = 1; static var role = 0
    static var cachedMessage: NoaIMChatMessageModel?
    func toolCheckMyGroup(with uid: String) -> LingIMGroupModel? { LingIMGroupModel(groupInformStatus: Self.notificationStatus, userGroupRole: Self.role) }
    static func sharedTool() -> Self { Self() }
    func myUserID() -> String { "A" }
    func isUserDatabaseReady() -> Bool { true }
    func toolCheckMyFriend(with uid: String) -> CachedPerson? { nil }
    func imSdkCheckGroupMember(with uid: String, groupID: String) -> CachedPerson { CachedPerson() }
    func toolGetOneChatMessage(withServiceMessageID id: String, sessionID: String) -> NoaIMChatMessageModel? {
        guard let model = Self.cachedMessage, model.record.serverID == id, model.record.conversationID == sessionID else { return nil }
        return model
    }
}
struct MediaModel {
    var imgWidth = 640.0; var imgHeight = 480.0; var imgSize = 120.0
    var imgName: String? = "img"; var thumbnailImg: String? = "thumb"
    var videoCoverW = 1920.0; var videoCoverH = 1080.0; var videoSize = 2000.0; var videoLength = 12.0
    var videoName: String? = "video"; var videoCover: String? = "cover"
    var geoImgWidth = 300.0; var geoImgHeight = 200.0
    var geoName: String? = "位置"; var geoLat: String? = "31.23"; var geoLng: String? = "121.47"; var geoImg: String? = "map"
    var stickersWidth = 256.0; var stickersHeight = 128.0; var stickersSize: Int64 = 150
    var stickersImg: String? = "sticker"; var stickersThumbnailImg: String? = "thumb"; var stickersId: String? = "pack.item"; var isStickersSet = true
}
final class NoaIMChatMessageModel {
    var serverMessage: IMServerMessage?
    var backDelServiceMsgID: String?
    var record = ChatMessageRecord(localID: "event", conversationID: "g", senderID: "system", senderName: "", type: 1000, timestamp: 1)
}
struct SDKChatMessageMapper {
    static func record(_ model: NoaIMChatMessageModel, userUID: String) -> ChatMessageRecord {
        var value = model.record
        if let server = model.serverMessage { value.text = ProductionMapper.systemSummary(server, userUID: userUID) }
        return value
    }
}
@main struct SDKMessageParityChecks {
    /// 使用实际生产摘要与媒体映射验证显示型/同步型事件及转发缓存所需字段。
    @MainActor static func main() async {
        func summary(_ kind: Int, mutate: (IMServerMessage) -> Void = { _ in }) -> String {
            let server = IMServerMessage(); server.sMsgType = ServerKind(rawValue: kind); mutate(server)
            return ProductionMapper.systemSummary(server, userUID: "A")
        }
        NoaIMSDKManager.notificationStatus = 0
        precondition(summary(504) { $0.customEvent.type = 101; $0.customEvent.content = #"{"state":"discard","from_id":"A","discard_reason":"cancel","mode":1}"# } == "已取消")
        precondition(summary(504) { $0.customEvent.type = 102; $0.customEvent.content = #"{"action":"new"}"# }.isEmpty, "群呼叫信令不能生成历史消息")
        precondition(summary(210).isEmpty, "关闭群通知不能暴露群系统摘要")
        NoaIMSDKManager.notificationStatus = 1
        precondition(summary(215) { $0.inviteConfirmGroupMessage?.isSilence = true }.isEmpty, "静默邀请不能显示摘要")
        precondition(summary(210) == "“张三”将群名称修改为：新的群🌳", "群名称事件必须有可读摘要")
        precondition(summary(208) == "“张三”设置了群公告")
        precondition(summary(219) == "“张三”删除了群公告")
        precondition(summary(204) { $0.kickGroupMessage?.uid = "A" } == "你已被移出群聊")
        precondition(summary(207).contains("开启了全员禁言"))
        precondition(summary(207) { $0.groupStatusMessage?.status = 0 }.contains("关闭了全员禁言"))
        precondition(summary(221).contains("禁言60分钟"))
        precondition(summary(221) { $0.groupSingleForbidMessage?.status = 0 }.contains("解除禁言"))
        precondition(summary(215) { $0.inviteConfirmGroupMessage?.type = 5 }.isEmpty)
        NoaIMSDKManager.role = 2
        precondition(summary(200) { $0.createGroupMessage?.inviteUidArray = NSMutableArray(object: UserInfo("C", "李四")) }.contains("邀请了“李四”加入群聊"))
        NoaIMSDKManager.role = 0
        precondition(summary(232).contains("7天后自动删除"))
        precondition(summary(232) { $0.scheduleDeleteMessage?.freq = 0 }.contains("关闭了消息自动删除"))
        for kind in [2, 505, 506, 515, 516, 517, 518] { precondition(summary(kind).isEmpty, "刷新型事件不能生成空气泡") }
        let image = ProductionMapper.media(MediaModel(), type: 1)
        precondition(image.mediaWidth == 640 && image.mediaHeight == 480)
        let video = ProductionMapper.media(MediaModel(), type: 2)
        precondition(video.mediaWidth == 1920 && video.mediaHeight == 1080 && video.size == 2000)
        let location = ProductionMapper.media(MediaModel(), type: 3)
        precondition(location.mediaWidth == 300 && location.latitude == "31.23" && location.longitude == "121.47")
        let sticker = ProductionMapper.media(MediaModel(), type: 12)
        precondition(sticker.mediaWidth == 256 && sticker.mediaHeight == 128 && sticker.stickerID == "pack.item" && sticker.isStickerSet)
        var events: [ChatEvent] = []
        let delegate = ProductionDelegate(userUID: "A", conversationID: "g", changed: { events.append($0) })
        let message = NoaIMChatMessageModel()
        let pin = IMServerMessage(); pin.sMsgType = ServerKind(rawValue: 516)
        message.serverMessage = pin; delegate.publish(message)
        precondition(events.count == 1)
        if case .pinsChanged = events[0] {} else { preconditionFailure("置顶事件必须专门刷新") }
        events = []; pin.groupMessageTop?.gid = "other"; delegate.publish(message)
        precondition(events.isEmpty, "其他群置顶不能刷新当前群")
        pin.sMsgType = ServerKind(rawValue: 517); pin.dialogUserMessageTop?.uid = "A"
        delegate.publish(message); precondition(events.count == 1)
        if case .pinsChanged = events[0] {} else { preconditionFailure("单聊置顶事件必须专门刷新") }
        events = []; pin.dialogUserMessageTop?.friendUid = "other"; delegate.publish(message)
        precondition(events.isEmpty)
        pin.sMsgType = ServerKind(rawValue: 2); delegate.publish(message)
        precondition(events.isEmpty, "空系统事件不能插入当前聊天")
        NoaIMSDKManager.notificationStatus = 0
        pin.sMsgType = ServerKind(rawValue: 215); delegate.publish(message)
        precondition(events.count == 2, "隐藏邀请仍需刷新成员与权限")
        precondition(!events.contains { if case .upsert = $0 { return true }; return false })
        events = []; pin.sMsgType = ServerKind(rawValue: 221); delegate.publish(message)
        precondition(events.count == 1)
        if case .permissionsChanged = events[0] {} else { preconditionFailure("隐藏禁言仍需刷新权限") }
        events = []; pin.sMsgType = ServerKind(rawValue: 208); delegate.publish(message)
        precondition(events.count == 1)
        if case .pinsChanged = events[0] {} else { preconditionFailure("隐藏公告仍需刷新置顶条") }
        NoaIMSDKManager.notificationStatus = 1
        precondition(summary(215) { $0.inviteConfirmGroupMessage?.informSwitch = 1; $0.inviteConfirmGroupMessage?.informUidArray = NSMutableArray(object: "B") }.isEmpty)
        precondition(!summary(215) { $0.inviteConfirmGroupMessage?.informSwitch = 1; $0.inviteConfirmGroupMessage?.informUidArray = NSMutableArray(object: "A") }.isEmpty)
        events = []
        let original = NoaIMChatMessageModel()
        original.record = ChatMessageRecord(localID: "original", serverID: "10", conversationID: "g", senderID: "B", senderName: "B", type: 0, text: "新引用🙂", timestamp: 10, state: .sent, referenceID: "9")
        NoaIMSDKManager.cachedMessage = original
        let recall = NoaIMChatMessageModel()
        recall.record = ChatMessageRecord(localID: "recall", serverID: "20", conversationID: "g", senderID: "B", senderName: "B", type: 8, timestamp: 20, state: .sent)
        recall.backDelServiceMsgID = "10"
        delegate.publish(recall)
        precondition(events.count == 1)
        if case let .upsert(value) = events[0] {
            precondition(value.localID == "original" && value.serverID == "10" && value.timestamp == 10 && value.status == .recalled && value.referenceID == "9", "SDK先派发控制记录再更新原条时必须仅更新原条")
        } else { preconditionFailure("撤回必须更新原条") }
        precondition(original.record.status == .normal, "代理只发布值，不能提前改写SDK对象")
        events = []; recall.backDelServiceMsgID = "missing"; delegate.publish(recall)
        precondition(events.isEmpty, "缺原条的撤回不能新增控制气泡")
        recall.backDelServiceMsgID = "10"; original.record.status = .deleted; delegate.publish(recall)
        precondition(events.isEmpty, "撤回不能恢复已删除原条")
        original.record.status = .normal
        recall.record = ChatMessageRecord(localID: "recall", conversationID: "other", senderID: "B", senderName: "B", type: 8, timestamp: 20)
        delegate.publish(recall); precondition(events.isEmpty, "其他会话撤回不能更新当前原条")
        // 真实SDK先给传输ACK，再用106通知拒收并更新原条；页面必须当场显示失败。
        let client = SuspendedChatClient()
        client.page = ChatPage(messages: [], hasMore: true)
        let store = ChatStore(client: client)
        let context = ChatContext(userUID: "me", tenantID: "club", sessionID: UUID(), route: ChatRoute(id: "peer", kind: .single, title: "好友", avatarURL: ""))
        await store.open(context)
        let single = ProductionDelegate(userUID: "me", conversationID: "peer", changed: { client.callback?($0) })
        store.input = "已拉黑后的消息"
        store.sendText()
        let outgoing = client.sent[0]
        client.callback?(.ack(localID: outgoing.localID, serverID: "sent-server", timestamp: 100))
        let rejected = NoaIMChatMessageModel()
        rejected.record = ChatMessageRecord(localID: "black-tip", serverID: "tip-server", conversationID: "peer", senderID: "peer", senderName: "好友", type: 1000, timestamp: 101, state: .sent)
        let black = IMServerMessage(); black.sMsgType = ServerKind(rawValue: 106)
        black.friendBlackMessage.msgId = outgoing.localID
        rejected.serverMessage = black
        single.publish(rejected)
        var sdkFailed = outgoing; sdkFailed.serverID = "sent-server"; sdkFailed.state = .failed
        client.callback?(.upsert(sdkFailed))
        precondition(store.messages.first { $0.localID == outgoing.localID }?.state == .failed,
                     "拉黑拒收必须即时覆盖传输ACK，不能返回列表重进才显示失败")
        precondition(store.messages.contains { $0.localID == "black-tip" && $0.text == "已拉黑" }, "保留旧端拉黑系统提示")
        client.callback?(.ack(localID: outgoing.localID, serverID: "sent-server", timestamp: 100))
        client.callback?(.upsert(outgoing))
        var oldSuccess = outgoing; oldSuccess.state = .sent; oldSuccess.serverID = "sent-server"
        client.page = ChatPage(messages: [oldSuccess], hasMore: false)
        await store.loadMore()
        precondition(store.messages.first { $0.localID == outgoing.localID }?.state == .failed && store.sendSuccessRevision == 1,
                     "拒收后的迟到ACK、发送中更新和历史成功快照不能重新显示成功")
        store.retry(outgoing.localID)
        precondition(store.messages.first { $0.localID == outgoing.localID }?.state == .sending, "主动重试允许解除拉黑后重发")
        client.callback?(.ack(localID: outgoing.localID, serverID: "retry-server", timestamp: 102))
        client.callback?(.failed(localID: outgoing.localID, reason: .timeout))
        precondition(store.messages.first { $0.localID == outgoing.localID }?.state == .sent && store.errorMessage == nil,
                     "重试后的真实ACK恢复成功，迟到网络超时仍不回退成功")

        // 拒收先于ACK同样有效，并覆盖所有走统一发送入口的正文类型。
        for type in [0, 1, 2, 4, 5, 6, 12, 18, 21] {
            client.policy.canUpload = true; client.policy.canUploadFile = true
            let message = ChatMessageRecord(localID: "type-\(type)", conversationID: "peer", senderID: "me", senderName: "我", type: type, timestamp: 200 + Int64(type))
            try! store.sendAttachment(message)
            black.friendBlackMessage.msgId = message.localID; black.friendBlackMessage.type = 2
            single.publish(rejected)
            client.callback?(.ack(localID: message.localID, serverID: "server-\(type)", timestamp: 300))
            precondition(store.messages.first { $0.localID == message.localID }?.state == .failed && store.messages.first { $0.localID == message.localID }?.failure == .blockedByPeer,
                         "对方拉黑且拒收先到时，后续ACK也不能放行该类型消息")
        }
        precondition(store.messages.first { $0.localID == outgoing.localID }?.state == .sent, "拒收只改变对应消息")

        store.input = "正常对照"; store.sendText()
        let control = client.sent.last!
        black.friendBlackMessage.msgId = control.localID
        black.friendBlackMessage.fUid = "other"; single.publish(rejected)
        black.friendBlackMessage.fUid = "peer"; black.to = "other-account"; single.publish(rejected)
        black.to = "me"; black.friendBlackMessage.type = 0; single.publish(rejected)
        black.friendBlackMessage.type = 1
        let groupDelegate = ProductionDelegate(userUID: "me", conversationID: "peer", isGroup: true, changed: { client.callback?($0) })
        groupDelegate.publish(rejected)
        precondition(store.messages.first { $0.localID == control.localID }?.state == .sending,
                     "其他好友、其他收件人、非法类型与群代理均不能拒收当前单聊")
        black.friendBlackMessage.msgId = ""; single.publish(rejected)
        black.friendBlackMessage.msgId = "missing"; single.publish(rejected)
        precondition(store.messages.first { $0.localID == control.localID }?.state == .sending, "缺失或未知消息ID不猜测最近消息")
        let received = ChatMessageRecord(localID: "received", conversationID: "peer", senderID: "peer", senderName: "好友", timestamp: 400, state: .sent)
        client.callback?(.upsert(received)); black.friendBlackMessage.msgId = received.localID; single.publish(rejected)
        precondition(store.messages.first { $0.localID == received.localID }?.state == .sent, "不能把收到的消息改为本人发送失败")
        client.callback?(.ack(localID: control.localID, serverID: "control-server", timestamp: 401))
        precondition(store.messages.first { $0.localID == control.localID }?.state == .sent, "正常单聊仍按真实ACK成功")
        let stopped = client.callback; store.close()
        black.friendBlackMessage.msgId = control.localID; single.publish(rejected)
        stopped?(.upsert(oldSuccess))
        precondition(store.messages.isEmpty, "关闭后旧拒收与SDK更新不得恢复会话")
        print("SDK message parity and blacklist checks passed")
    }
}
