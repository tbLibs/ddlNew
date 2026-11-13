import Foundation

/// The SDK remains the owner of delivery/ACK. This operation only submits after revalidating permissions.
@MainActor enum ChatMediaShareOperation {
    static func send(_ attachment: ChatAttachment, context: ChatContext,
                     validate: () throws -> Void,
                     authorize: () async throws -> Void,
                     upload: (ChatAttachment) async throws -> ChatUploadedAttachment,
                     enqueue: (ChatMessageRecord) throws -> Void) async throws {
        try Task.checkCancellation(); try validate()
        guard [1, 2].contains(attachment.type), attachment.bytes > 0,
              attachment.duration.isFinite, attachment.width.isFinite, attachment.height.isFinite else { throw ChatClientError.invalidResponse }
        try await authorize()
        try Task.checkCancellation(); try validate()
        let result = try await upload(attachment)
        try Task.checkCancellation(); try validate()
        try await authorize()
        try Task.checkCancellation(); try validate()
        var record = ChatMessageRecord(localID: UUID().uuidString, conversationID: context.route.id,
            senderID: context.userUID, senderName: L10n.tr("我"), type: attachment.type,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000))
        record.resource = result.resource; record.thumbnail = result.thumbnail
        record.fileName = attachment.name; record.size = attachment.bytes
        record.duration = attachment.duration; record.mediaWidth = attachment.width; record.mediaHeight = attachment.height
        try enqueue(record)
    }
}
