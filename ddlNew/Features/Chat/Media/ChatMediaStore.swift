//
//  ChatMediaStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import Combine

@MainActor final class ChatMediaStore: ObservableObject {
    @Published private(set) var isUploading = false
    @Published private(set) var progress = 0.0
    @Published var errorMessage: String?
    private let client: any ChatMediaClient
    /// 注入真实或暂停上传客户端。
    init(client: any ChatMediaClient) { self.client = client }
    private var generation = UUID()
    private var pendingPreview: (id: String, discard: (String) -> Void)?

    /// 上传完成仍只入真实消息队列，最终成功由ACK确认。
    func send(_ attachment: ChatAttachment, context: ChatContext,
              stage: ((ChatMessageRecord) throws -> Void)? = nil,
              discard: ((String) -> Void)? = nil,
              enqueue: (ChatMessageRecord) throws -> Void) async {
        guard !isUploading else { return }
        guard attachment.bytes > 0 else { errorMessage = "附件为空，请重新选择"; return }
        if attachment.type == 4 && (attachment.bytes < 1024 || !attachment.duration.isFinite || attachment.duration < 1 || attachment.duration > 60) { errorMessage = "录音太短或超过60秒，请重新录制"; return }
        let run = generation; isUploading = true; progress = 0; errorMessage = nil
        defer { if generation == run { isUploading = false } }
        var message = ChatMessageRecord(localID: UUID().uuidString, conversationID: context.route.id,
            senderID: context.userUID, senderName: "我", type: attachment.type,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000))
        message.fileName = attachment.name; message.size = attachment.bytes
        message.duration = attachment.duration; message.mediaWidth = attachment.width; message.mediaHeight = attachment.height
        do {
            if [1, 2].contains(attachment.type), let stage, let discard {
                message.localMediaPreviewURL = attachment.type == 2 ? attachment.previewFile : attachment.file
                message.isMediaUploading = true
                try stage(message)
                pendingPreview = (message.localID, discard)
            }
            let uploaded = try await client.upload(attachment, context: context) { [weak self] value in
                guard let self, self.generation == run else { return }; self.progress = value
            }
            guard generation == run else { return }
            if Task.isCancelled {
                if let pendingPreview { pendingPreview.discard(pendingPreview.id); self.pendingPreview = nil }
                return
            }
            message.localMediaPreviewURL = nil; message.isMediaUploading = false
            message.resource = uploaded.resource; message.thumbnail = uploaded.thumbnail
            try enqueue(message)
            pendingPreview = nil
        } catch {
            if generation == run {
                if let pendingPreview { pendingPreview.discard(pendingPreview.id); self.pendingPreview = nil }
                if !(error is CancellationError) { errorMessage = error.localizedDescription }
            }
        }
    }

    /// 界面取消会撤销旧上传身份，迟到完成不能再提交消息。
    func cancel() {
        generation = UUID()
        if let pendingPreview { pendingPreview.discard(pendingPreview.id); self.pendingPreview = nil }
        client.cancel(); isUploading = false; progress = 0
    }

}
