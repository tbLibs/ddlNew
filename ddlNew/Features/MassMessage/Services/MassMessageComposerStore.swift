//
//  MassMessageComposerStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/23.
//

import Foundation
import Combine

@MainActor final class MassMessageComposerStore: ObservableObject {
    let context: ChatContext
    let original: MassMessageRecord?
    @Published var text = ""
    @Published var label = ""
    @Published var selection: [MassMessageRecipient] = []
    @Published private(set) var attachment: ChatAttachment?
    @Published private(set) var busy = false
    @Published private(set) var progress: Double = 0
    @Published var errorMessage: String?
    private let client: any MassMessageClient
    private let media: any ChatMediaClient
    private let isCurrent: @MainActor (ChatContext) -> Bool
    private let allowed: @MainActor () -> Bool
    private var generation = UUID()
    private var usesOriginalBody: Bool
    private var createdLabel: (fingerprint: String, id: String)?
    private var submitted = false
    private var activeSend: Task<Bool, Never>?

    init(context: ChatContext, reusing: MassMessageRecord? = nil, client: (any MassMessageClient)? = nil,
         media: (any ChatMediaClient)? = nil,
         isCurrent: @escaping @MainActor (ChatContext) -> Bool = { ChatRuntime.shared.isCurrent($0) },
         allowed: @escaping @MainActor () -> Bool = { UserRoleAuthorityStore.shared.current?.allows("groupHairAssistant") == true }) {
        self.context = context; original = reusing; self.client = client ?? SDKMassMessageClient(context: context)
        self.media = media ?? SDKChatMediaClient(); self.isCurrent = isCurrent; self.allowed = allowed
        text = reusing?.body["content"] ?? ""; label = reusing?.label ?? ""; usesOriginalBody = reusing?.type != nil && reusing?.type != 0
        ChatRuntime.shared.registerCleanup(owner: self) { [weak self] in self?.close() }
    }
    var messageType: Int { attachment?.type ?? (usesOriginalBody ? original?.type ?? 0 : 0) }
    var canSubmit: Bool {
        !busy && !submitted && isCurrent(context) && allowed()
        && (try? MassMessagePayload.validate(text: text, label: label, recipients: selection, reusing: original?.labelID, type: messageType)) != nil
    }
    /// 临时原件归编辑页所有，更换、退出或成功提交才释放。
    func replaceAttachment(_ value: ChatAttachment?) {
        guard !busy else { Self.remove(value); return }
        Self.remove(attachment); attachment = value; usesOriginalBody = false; errorMessage = nil
    }
    /// 独立持有发送Task，弹层生命周期不会意外取消已提交的服务端任务。
    func send() async -> Bool {
        guard !busy, !submitted else { return false }
        busy = true; errorMessage = nil; progress = 0
        let run = generation
        let task = Task { await self.performSend(run: run) }
        activeSend = task
        let success = await task.value
        if generation == run { busy = false; activeSend = nil }
        return success
    }
    private func performSend(run: UUID) async -> Bool {
        do {
            try validate(run)
            let type = messageType, label = label.trimmingCharacters(in: .whitespacesAndNewlines), selected = selection
            try MassMessagePayload.validate(text: text, label: label, recipients: selected, reusing: original?.labelID, type: type)
            let body: [String: Any]
            if let attachment {
                let uploaded = try await media.upload(attachment, context: context) { [weak self] value in
                    guard let self, self.generation == run, self.isCurrent(self.context) else { return }; self.progress = value
                }
                try validate(run)
                body = Self.attachmentBody(attachment, uploaded: uploaded)
            } else if usesOriginalBody, let original {
                body = Self.reusedBody(original)
            } else { body = ["content": text.trimmingCharacters(in: .whitespacesAndNewlines), "ext": ""] }
            let bytes = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            guard let json = String(data: bytes, encoding: .utf8) else { throw MassMessageError.invalidResponse }
            let labelID: String
            if let original { labelID = original.labelID }
            else {
                let fingerprint = label + "\u{0}" + Set(selected.map(\.id)).sorted().joined(separator: "\u{0}")
                if let cached = createdLabel, cached.fingerprint == fingerprint { labelID = cached.id }
                else {
                    labelID = try await client.create(label: label, recipients: selected)
                    try validate(run); createdLabel = (fingerprint, labelID)
                }
            }
            try validate(run)
            try await client.send(labelID: labelID, type: type, body: json)
            guard run == generation, isCurrent(context) else { return false }
            submitted = true; Self.remove(attachment); attachment = nil
            return true
        } catch {
            if generation == run, isCurrent(context), !(error is CancellationError) { errorMessage = error.localizedDescription }
            return false
        }
    }
    /// 各媒体字段严格对齐群发body协议，不能直接使用普通聊天wire结构。
    static func attachmentBody(_ attachment: ChatAttachment, uploaded: ChatUploadedAttachment) -> [String: Any] {
        let preview = uploaded.thumbnail.isEmpty ? uploaded.resource : uploaded.thumbnail
        switch attachment.type {
        case 1: return ["name": uploaded.resource, "iImg": preview, "size": attachment.bytes, "width": attachment.width, "height": attachment.height, "ext": ""]
        case 2: return ["name": uploaded.resource, "cImg": uploaded.thumbnail, "cWidth": attachment.width, "cHeight": attachment.height, "length": attachment.duration, "ext": ""]
        default: return ["path": uploaded.resource, "name": attachment.name, "type": attachment.file.pathExtension, "size": attachment.bytes, "ext": ""]
        }
    }
    static func reusedBody(_ record: MassMessageRecord) -> [String: Any] {
        var body: [String: Any] = record.body
        for key in ["size", "width", "height", "cWidth", "cHeight", "length"] {
            if let value = record.body[key], let number = Double(value), number.isFinite { body[key] = number }
        }
        return body
    }
    private func validate(_ run: UUID) throws {
        try Task.checkCancellation()
        guard run == generation, isCurrent(context) else { throw MassMessageError.sessionExpired }
        guard allowed() else { throw MassMessageError.message("当前账号没有群发权限") }
    }
    static func remove(_ value: ChatAttachment?) {
        guard let value else { return }; try? FileManager.default.removeItem(at: value.file)
        if let preview = value.previewFile { try? FileManager.default.removeItem(at: preview) }
    }
    func close() {
        generation = UUID(); activeSend?.cancel(); activeSend = nil; client.cancel(); media.cancel()
        Self.remove(attachment); attachment = nil; text = ""; selection = []; label = ""; busy = false; errorMessage = nil
    }
}
