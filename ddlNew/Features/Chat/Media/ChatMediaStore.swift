//
//  ChatMediaStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import Combine

@MainActor final class ChatMediaStore: ObservableObject, ChatMediaRetryClient {
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
              failed: ((ChatMessageRecord) -> Void)? = nil,
              retrying: ChatMessageRecord? = nil,
              enqueue: (ChatMessageRecord) throws -> Void) async {
        guard !isUploading else { return }
        guard attachment.bytes > 0 else { errorMessage = "附件为空，请重新选择"; return }
        if attachment.type == 4 && (attachment.bytes < 1024 || !attachment.duration.isFinite || attachment.duration < 1 || attachment.duration > 60) { errorMessage = "录音太短或超过60秒，请重新录制"; return }
        let run = generation; isUploading = true; progress = 0; errorMessage = nil
        defer { if generation == run { isUploading = false } }
        var message = retrying ?? ChatMessageRecord(localID: UUID().uuidString, conversationID: context.route.id,
            senderID: context.userUID, senderName: "我", type: attachment.type,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000))
        message.fileName = attachment.name; message.size = attachment.bytes
        message.duration = attachment.duration; message.mediaWidth = attachment.width; message.mediaHeight = attachment.height
        var retained: ChatAttachment?
        do {
            if [1, 2].contains(attachment.type), let stage, let discard {
                let owned = try await Task.detached { try ChatUploadFiles.retain(attachment) }.value
                guard generation == run, !Task.isCancelled else {
                    if retrying == nil { ChatUploadFiles.remove(owned.file) }
                    return
                }
                retained = owned
                message.localMediaFileURL = owned.file
                message.state = .sending; message.failure = nil
                message.localMediaPreviewURL = attachment.type == 2 ? owned.previewFile : owned.file
                message.isMediaUploading = true
                try stage(message)
                if let retrying, let failed {
                    pendingPreview = (message.localID, { _ in failed(retrying) })
                } else { pendingPreview = (message.localID, { id in discard(id); ChatUploadFiles.remove(owned.file) }) }
            }
            let uploaded = try await client.upload(retained ?? attachment, context: context) { [weak self] value in
                guard let self, self.generation == run else { return }; self.progress = value
            }
            guard generation == run else { return }
            if Task.isCancelled {
                if let pendingPreview { pendingPreview.discard(pendingPreview.id); self.pendingPreview = nil }
                return
            }
            message.localMediaPreviewURL = nil; message.localMediaFileURL = nil; message.isMediaUploading = false
            message.resource = uploaded.resource; message.thumbnail = uploaded.thumbnail
            try enqueue(message)
            pendingPreview = nil
            ChatUploadFiles.remove(retained?.file)
        } catch {
            if generation == run {
                if error is CancellationError || Task.isCancelled {
                    if let pendingPreview { pendingPreview.discard(pendingPreview.id); self.pendingPreview = nil }
                    if retrying == nil { ChatUploadFiles.remove(retained?.file) }
                } else {
                    let hasFailureBubble = pendingPreview != nil && retained != nil && failed != nil
                    if pendingPreview != nil, let retained {
                        message.state = .failed; message.failure = .unknown; message.isMediaUploading = false
                        message.localMediaFileURL = retained.file
                        message.localMediaPreviewURL = attachment.type == 2 ? retained.previewFile : retained.file
                        failed?(message)
                        pendingPreview = nil
                    } else if retrying == nil { ChatUploadFiles.remove(retained?.file) }
                    // 已有失败气泡承载状态，图片/视频发送失败不重复弹Toast。
                    if !hasFailureBubble { errorMessage = error.localizedDescription }
                }
            }
        }
    }

    /// 原条重传保留localID，缺少原件时保持失败并提示重新选择。
    func retry(_ message: ChatMessageRecord, context: ChatContext,
               stage: @escaping (ChatMessageRecord) throws -> Void,
               discard: @escaping (String) -> Void,
               failed: @escaping (ChatMessageRecord) -> Void,
               enqueue: @escaping (ChatMessageRecord) throws -> Void) async {
        guard !isUploading else { errorMessage = "附件正在发送，请稍后再试"; return }
        guard let file = message.localMediaFileURL, FileManager.default.fileExists(atPath: file.path) else {
            errorMessage = "本地附件已丢失，请重新选择发送"; return
        }
        let attachment = ChatAttachment(file: file, type: message.type, name: message.fileName,
            bytes: message.size, duration: message.duration, width: message.mediaWidth, height: message.mediaHeight,
            previewFile: message.type == 2 ? message.localMediaPreviewURL : nil)
        await send(attachment, context: context, stage: stage, discard: discard,
                   failed: failed, retrying: message, enqueue: enqueue)
    }

    /// 界面取消会撤销旧上传身份，迟到完成不能再提交消息。
    func cancel() {
        generation = UUID()
        if let pendingPreview { pendingPreview.discard(pendingPreview.id); self.pendingPreview = nil }
        client.cancel(); isUploading = false; progress = 0
    }

}
