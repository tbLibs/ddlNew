import Foundation
struct CIMChatType { var rawValue: Int; init?(rawValue: Int) { self.rawValue = rawValue } }
struct CIMChatMessageType { var rawValue: UInt; init?(rawValue: UInt) { self.rawValue = rawValue } }
struct CIMChatMessageSendType { var rawValue: Int; init?(rawValue: Int) { self.rawValue = rawValue } }
struct TestUser { var nickname = "A"; var avatar = "" }
struct UserSessionStore { static let shared = UserSessionStore(); var currentUser: TestUser? { TestUser() } }
final class NoaIMChatMessageModel {
    var msgID: String?; var serviceMsgID: String?; var fromID: String?; var toID: String?
    var fromNickname = ""; var fromIcon = ""
    var chatType = CIMChatType(rawValue: 0)!; var messageType = CIMChatMessageType(rawValue: 0)!; var messageSendType = CIMChatMessageSendType(rawValue: 0)!
    var messageStatus = 1; var isAck = false; var isEncry = false; var currentVersionMessageOK = true
    var sendTime: Int64 = 0; var referenceMsgId = ""; var textContent = ""; var atContent = ""; var showContent = ""; var atUsersInfoList: [[String: String]] = []
    var imgName = ""; var thumbnailImg = ""; var imgSize: Float = 0; var imgWidth: Float = 0; var imgHeight: Float = 0
    var videoName = ""; var videoCover = ""; var videoLength: Float = 0; var videoCoverW: Float = 0; var videoCoverH: Float = 0; var videoSize: Float = 0
    var voiceName = ""; var voiceLength: Float = 0; var voiceExt = ""
    var stickersImg = ""; var stickersThumbnailImg = ""; var stickersId = ""; var isStickersSet = false; var stickersSize: Int64 = 0; var stickersWidth: Float = 0; var stickersHeight: Float = 0
    var fileType = ""; var filePath: String?; var fileName: String?; var showFileName: String?; var fileSize: Float = 0
}
@main struct FileNameContractChecks {
    static func main() {
        let context = ChatContext(userUID: "A", tenantID: "club", sessionID: UUID(), route: ChatRoute(id: "B", kind: .single, title: "B", avatarURL: ""))
        let client = ProductionFileClient()
        for name in ["qa-file-20261015.txt", "读我-说明🙂.txt", "plain.txt", "-leading.txt"] {
            var message = ChatMessageRecord(localID: "1234-5678-90AB", conversationID: "B", senderID: "A", senderName: "A", type: 5, timestamp: 1)
            message.fileName = name; message.resource = "controlled-resource"; message.size = 137
            let model = client.makeModel(message, context: context)
            precondition(model.showFileName == name && model.fileSize == 137 && model.fileType == "txt")
            // SDK发送边界FileMessage.name=fileName；接收边界只移除首个'-'前的协议前缀。
            // 来源：真实LingIMModelTool.m126-130/393，与旧NoaMessageSendHander.m591/603配对。
            let wireName = model.fileName!
            let received = NoaIMChatMessageModel(); received.fileName = wireName; received.filePath = model.filePath; received.fileSize = model.fileSize
            if let separator = wireName.firstIndex(of: "-") { received.showFileName = String(wireName[wireName.index(after: separator)...]) }
            else { received.showFileName = wireName }
            let result = ProductionFileMapper.record(received)
            precondition(result.fileName == name && result.size == 137 && result.resource == message.resource, "真实SDK首分隔符解码后必须保留原文件名")
            precondition(client.makeModel(message, context: context).fileName == wireName, "重发只复用稳定前缀，不能叠加原名或UUID残段")
        }
        var text = ChatMessageRecord(localID: "text-id", conversationID: "B", senderID: "A", senderName: "A", type: 0, text: "普通正文", timestamp: 1)
        text.fileName = "unused-field"
        precondition(client.makeModel(text, context: context).textContent == "普通正文" && client.makeModel(text, context: context).fileName == "unused-field", "前缀转换只作用文件正文")
        print("File name SDK contract checks: 13 passed")
    }
}
