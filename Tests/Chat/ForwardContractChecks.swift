import Foundation
// SDK边界采用匿名对象；实际生产转发方法从源码提取编译，完整SDK编译由Xcode验证。
struct IMChatMessage_MessageType { let rawValue: Int; init?(rawValue: Int) { self.rawValue = rawValue } }
final class TextMessage { var content = ""; var translate = "" }
final class ImageMessage { var ext = "" }
final class GEOMessage {
    var lat = ""; var lng = ""; var name = ""; var cImg = ""; var ext = ""; var details = ""
    var cWidth: Int32 = 0; var cHeight: Int32 = 0
}
final class NoaIMChatMessageModel {
    var payload = ChatMessageRecord(localID: "source", conversationID: "source-chat", senderID: "B", senderName: "B", timestamp: 100)
    var messageStatus = 1; var currentVersionMessageOK = true; var chatMessageReaded = false
    var messageSendType = CIMChatMessageSendType(rawValue: 0)!
    var videoSize = 2000.0
    var sendTime: Int64 = 100
    var referenceMsgId = "source-only"
    var messageType = IMChatMessage_MessageType(rawValue: 0)!
    var atUsersInfoList: Any?
    var atContent: String?
    var showContent: String?
    var geoLat: String? = "31.23"; var geoLng: String? = "121.47"; var geoName: String? = "位置"; var geoImg: String? = "map"; var geoExt: String? = "ext"; var geoDetails: String? = "details"
    var geoImgWidth: Float = 300; var geoImgHeight: Float = 200
    var imgExt: String?
}
final class IMChatMessage {
    var payload = ChatMessageRecord(localID: "source", conversationID: "source-chat", senderID: "B", senderName: "B", timestamp: 100)
    var msgId = "source"; var sMsgId = ""; var from = "B"; var to = "source-chat"
    var cType = ChatType(rawValue: 0)!; var nick = "B"; var icon = ""
    func copy() -> Any { let clone = IMChatMessage(); clone.payload = payload; clone.mType = mType; clone.sendTime = sendTime; clone.referenceMsgId = referenceMsgId; clone.textMessage = textMessage; clone.geoMessage = geoMessage; return clone }
    var sendTime: Int64 = 999999
    var referenceMsgId = "source-only"
    var isAck = false
    var isEncry = false
    var mType = IMChatMessage_MessageType(rawValue: 0)!
    var textMessage = TextMessage()
    var imageMessage = ImageMessage()
    var geoMessage = GEOMessage()
}
struct LingIMModelTool {
    static func shared() -> Self { Self() }
    /// 模拟真实SDK普通发送转换重写时间并保留引用和@类型的边界。
    func getChatMessageModel(fromLingIMChatMessageModel original: NoaIMChatMessageModel) -> IMChatMessage {
        let value = IMChatMessage(); value.payload = original.payload; value.mType = original.messageType
        value.referenceMsgId = original.referenceMsgId; value.textMessage.translate = "旧翻译"
        return value
    }
    func getChatMessageModel(from wire: IMChatMessage) -> NoaIMChatMessageModel {
        let model = NoaIMChatMessageModel()
        var value = ChatMessageRecord(localID: wire.msgId, serverID: wire.sMsgId, conversationID: wire.to, senderID: wire.from, senderName: wire.nick, type: wire.mType.rawValue, text: wire.textMessage.content, timestamp: wire.sendTime)
        value.referenceID = wire.referenceMsgId; value.resource = wire.payload.resource; value.thumbnail = wire.payload.thumbnail
        value.latitude = wire.payload.latitude; value.longitude = wire.payload.longitude
        value.stickerID = wire.payload.stickerID; value.isStickerSet = wire.payload.isStickerSet
        value.mediaWidth = wire.payload.mediaWidth; value.mediaHeight = wire.payload.mediaHeight
        model.payload = value; return model
    }
}
struct CIMChatMessageSendType { let rawValue: Int; init?(rawValue: Int) { self.rawValue = rawValue } }
struct ChatType { let rawValue: Int; init?(rawValue: Int) { self.rawValue = rawValue } }
final class ToMessage { var chatType = ChatType(rawValue: 1)! }
struct FakeSDK { func toolInsertOrUpdateSession(with model: NoaIMChatMessageModel, isRemind: Bool) {} }
struct StubTarget { func makeModel(_ record: ChatMessageRecord, context: ChatContext) -> NoaIMChatMessageModel { let model = NoaIMChatMessageModel(); model.payload = record; return model } }
struct UserSessionStore { var currentUser: User? { User() }; struct User { let nickname = "本人"; let avatar = "my-avatar" } }
// 对齐生产属性访问形式。
extension UserSessionStore { static var shared: Self { Self() } }
struct SDKChatMessageMapper {
    static func record(_ model: NoaIMChatMessageModel, userUID: String) -> ChatMessageRecord {
        var value = model.payload; value.state = ChatSendState(rawValue: model.messageSendType.rawValue)!; value.isRead = model.chatMessageReaded
        return value
    }
}
@main struct ForwardContractChecks {
    /// 校验生产转发转换的时间、引用、@正文及附件扩展字段。
    static func main() {
        let source = NoaIMChatMessageModel()
        let forwarder = ProductionForwarder()
        let plain = forwarder.forwardingMessage(source)
        precondition(plain.sendTime == 100, "合并转发条目不能使用当前发送时间")
        precondition(plain.referenceMsgId.isEmpty, "跨会话引用必须清除")
        precondition(plain.textMessage.translate.isEmpty)
        precondition(plain.isAck && plain.isEncry)
        precondition(source.referenceMsgId == "source-only", "转换不能修改原消息缓存")
        source.messageType = IMChatMessage_MessageType(rawValue: 10)!
        source.atContent = "Hi \u{000b}U\u{000b} and \u{000b}-1\u{000b}"; source.atUsersInfoList = [["U": "张三"], ["-1": "所有人"]]
        let mention = forwarder.forwardingMessage(source)
        precondition(mention.mType.rawValue == 0, "转发不能携带来源群@身份")
        precondition(mention.textMessage.content == "Hi @张三 and @所有人", mention.textMessage.content)
        precondition(mention.referenceMsgId.isEmpty && mention.sendTime == 100)
        source.messageType = IMChatMessage_MessageType(rawValue: 1)!
        source.imgExt = "图片扩展"
        let image = forwarder.forwardingMessage(source)
        precondition(image.imageMessage.ext == "图片扩展")
        precondition(image.mType.rawValue == 1)
        source.messageType = IMChatMessage_MessageType(rawValue: 7)!
        let location = forwarder.forwardingMessage(source)
        precondition(location.mType.rawValue == 3)
        precondition(location.geoMessage.lat == "31.23" && location.geoMessage.lng == "121.47")
        precondition(location.geoMessage.cWidth == 300 && location.geoMessage.cHeight == 200)
        var sourceRecord = ChatMessageRecord(localID: "source", serverID: "old-server", conversationID: "old-chat", senderID: "B", senderName: "张三", type: 12, timestamp: 100)
        sourceRecord.latitude = "31.23"; sourceRecord.longitude = "121.47"; sourceRecord.stickerID = "pack.item"; sourceRecord.isStickerSet = true
        sourceRecord.mediaWidth = 640; sourceRecord.mediaHeight = 480; sourceRecord.resource = "attachment"
        source.payload = sourceRecord; source.messageType = IMChatMessage_MessageType(rawValue: 12)!
        let entry = forwarder.forwardingMessage(source)
        let route = ChatRoute(id: "new-chat", kind: .group, title: "新会话", avatarURL: "")
        let destination = ChatContext(userUID: "A", tenantID: "t", sessionID: UUID(), route: route)
        let cached = forwarder.cache(ordered: [sourceRecord], entries: [entry], models: [source], ids: ["new-local"], serverIDs: ["new-server"], recipient: route, destination: destination, receiver: ToMessage())[0]
        precondition(cached.localID == "new-local" && cached.serverID == "new-server")
        precondition(cached.conversationID == "new-chat" && cached.senderID == "A")
        precondition(cached.referenceID.isEmpty && cached.state == .sent && cached.isRead)
        precondition(cached.latitude == "31.23" && cached.longitude == "121.47")
        precondition(cached.stickerID == "pack.item" && cached.isStickerSet)
        precondition(cached.mediaWidth == 640 && cached.mediaHeight == 480)
        precondition(source.payload.localID == "source" && source.payload.conversationID == "old-chat")
        print("Forward wire/cache contract checks: 20 passed")
    }
}
