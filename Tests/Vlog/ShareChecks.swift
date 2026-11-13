import Foundation
@main struct ShareChecks {
    @MainActor static func main() async throws {
        let context = ChatContext(userUID: "owner", tenantID: "tenant", sessionID: UUID(), route: ChatRoute(id: "group", kind: .group, title: "Test", avatarURL: ""))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([1,2,3]).write(to: file); defer { try? FileManager.default.removeItem(at: file) }
        let attachment = ChatAttachment(file: file, type: 2, name: "clip.mov", bytes: 3, duration: 12, width: 1080, height: 1920, previewFile: file)
        var events: [String] = [], message: ChatMessageRecord?
        try await ChatMediaShareOperation.send(attachment, context: context, validate: { events.append("validate") }, authorize: { events.append("permission") }, upload: { _ in events.append("upload"); return ChatUploadedAttachment(resource: "video", thumbnail: "cover") }, enqueue: { message = $0; events.append("queue") })
        precondition(events == ["validate", "permission", "validate", "upload", "validate", "permission", "validate", "queue"])
        precondition(message?.type == 2 && message?.duration == 12 && message?.thumbnail == "cover" && message?.resource == "video")
        precondition(message?.mediaWidth == 1080 && message?.mediaHeight == 1920 && message?.senderID == "owner")
        precondition(FileManager.default.fileExists(atPath: file.path))
        var uploaded = false, enqueued = false
        do {
            try await ChatMediaShareOperation.send(attachment, context: context, validate: {}, authorize: { throw ChatClientError.sessionExpired }, upload: { _ in uploaded = true; return ChatUploadedAttachment(resource: "", thumbnail: "") }, enqueue: { _ in enqueued = true })
            preconditionFailure("permission denial accepted")
        } catch { }
        precondition(!uploaded && !enqueued)
        var current = true
        do {
            try await ChatMediaShareOperation.send(attachment, context: context, validate: { if !current { throw ChatClientError.sessionExpired } }, authorize: {}, upload: { _ in current = false; return ChatUploadedAttachment(resource: "video", thumbnail: "cover") }, enqueue: { _ in enqueued = true })
            preconditionFailure("stale session queued")
        } catch { }
        precondition(!enqueued)
        do {
            try await ChatMediaShareOperation.send(attachment, context: context, validate: {}, authorize: {}, upload: { _ in throw CancellationError() }, enqueue: { _ in enqueued = true })
            preconditionFailure("cancel queued")
        } catch { }
        precondition(!enqueued)
        print("Vlog share permission, ordering, media fields, account switch and cancellation checks passed")
    }
}
