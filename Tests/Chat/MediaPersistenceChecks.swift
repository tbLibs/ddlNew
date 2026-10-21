import Foundation

struct CIMChatMessageSendType {
    let rawValue: UInt
    init?(rawValue: UInt) { self.rawValue = rawValue }
}
final class NoaIMChatMessageModel {
    var messageStatus = 1
    var messageSendType = CIMChatMessageSendType(rawValue: 0)!
    var localImgName: String?
    var localVideoName: String?
    var localVideoCover: String?
}
@MainActor final class LocalMessageDatabase {
    var existing: NoaIMChatMessageModel?
    var saved: NoaIMChatMessageModel?
    var acceptsWrites = true
    func toolGetOneChatMessage(withMessageID: String, sessionID: String) -> NoaIMChatMessageModel? { existing }
    func toolInsertOrUpdateChatMessage(with model: NoaIMChatMessageModel) -> Bool {
        if acceptsWrites { saved = model }; return acceptsWrites
    }
}
@MainActor final class PersistenceClient {
    let sdk = LocalMessageDatabase()
    var active = true
    func validate(_ context: ChatContext) throws { if !active { throw ChatClientError.sessionExpired } }
    func makeModel(_ message: ChatMessageRecord, context: ChatContext) -> NoaIMChatMessageModel { NoaIMChatMessageModel() }
}
@main struct MediaPersistenceChecks {
    @MainActor static func main() throws {
        let context = ChatContext(userUID: "u", tenantID: "club", sessionID: UUID(), route: ChatRoute(id: "p", kind: .single, title: "", avatarURL: ""))
        let client = PersistenceClient()
        var source = ChatMessageRecord(localID: "failed-photo", conversationID: "p", senderID: "u", senderName: "我", type: 1, timestamp: 123, state: .failed)
        source.localMediaFileURL = ChatUploadFiles.directory.appendingPathComponent("C9AE020D-E710-46B8-BD96-04594B2DD4E7/media.jpg")
        source.localMediaPreviewURL = source.localMediaFileURL
        try client.saveFailedMedia(source, context: context)
        let saved = client.sdk.saved!
        precondition(saved.messageSendType.rawValue == 2 && saved.localImgName == "ddlNewUpload:C9AE020D-E710-46B8-BD96-04594B2DD4E7/media.jpg", "生产保存方法必须持久化失败态及可迁移的相对原件路径")
        var bare = source; bare.localMediaFileURL = nil; bare.localMediaPreviewURL = nil
        let restored = restore(bare, saved, userUID: "u")
        precondition(restored.localMediaFileURL == source.localMediaFileURL && restored.localMediaPreviewURL == source.localMediaFileURL, "生产映射方法必须从本机消息恢复图片与重传原件")
        precondition(restore(bare, saved, userUID: "other").localMediaFileURL == nil, "其他用户的本机路径不能复用")
        saved.localImgName = "ddlNewUpload:../outside.jpg"
        precondition(restore(bare, saved, userUID: "u").localMediaFileURL == nil, "相对路径不得逃逸附件目录")
        source.type = 2
        source.localMediaFileURL = ChatUploadFiles.directory.appendingPathComponent("C9AE020D-E710-46B8-BD96-04594B2DD4E7/media.mp4")
        source.localMediaPreviewURL = ChatUploadFiles.directory.appendingPathComponent("C9AE020D-E710-46B8-BD96-04594B2DD4E7/cover.jpg")
        try client.saveFailedMedia(source, context: context)
        var videoBare = source; videoBare.localMediaFileURL = nil; videoBare.localMediaPreviewURL = nil
        let restoredVideo = restore(videoBare, client.sdk.saved!, userUID: "u")
        precondition(restoredVideo.localMediaFileURL == source.localMediaFileURL && restoredVideo.localMediaPreviewURL == source.localMediaPreviewURL, "视频原件和封面必须独立恢复")
        client.sdk.saved = nil
        let sent = NoaIMChatMessageModel(); sent.messageSendType = CIMChatMessageSendType(rawValue: 1)!
        client.sdk.existing = sent
        try client.saveFailedMedia(source, context: context)
        precondition(client.sdk.saved == nil, "迟到失败不得覆盖SDK成功消息")
        sent.messageSendType = CIMChatMessageSendType(rawValue: 0)!; sent.messageStatus = 0
        try client.saveFailedMedia(source, context: context)
        precondition(client.sdk.saved == nil, "迟到失败不得复活已删除原条")
        client.sdk.existing = nil; client.sdk.acceptsWrites = false
        do { try client.saveFailedMedia(source, context: context); preconditionFailure("数据库拒绝必须报错") } catch {}
        client.active = false
        do { try client.saveFailedMedia(source, context: context); preconditionFailure("AUTH结束不得写库") } catch {}
        print("Media persistence checks: image/video restore, relative paths, ownership, success/delete protection and write failures passed")
    }
}
