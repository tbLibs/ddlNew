//
//  ChatVoicePlayback.swift
//  ddlNew
//
//  Created by taobo on 2026/10/19.
//

import Foundation
import Combine

/// 一个聊天只播放一条语音，复用原下载、解包及删除失效边界。
@MainActor final class ChatVoicePlayback: ObservableObject {
    @Published private(set) var messageID: String?
    let preview: ChatMediaPreviewStore
    private var task: Task<Void, Never>?
    private var generation = UUID()

    init() { preview = ChatRuntime.shared.makePreviewStore() }

    /// 同一条再次点击停止，换条立即取消旧下载；只有实际play成功才上报已读。
    func toggle(_ message: ChatMessageRecord, context: ChatContext,
                onPlayed: @escaping () -> Void, onError: @escaping (String) -> Void) {
        let wasActive = messageID == message.id && (preview.loading || preview.playing)
        stop()
        guard !wasActive, ChatRuntime.shared.isCurrent(context) else { return }
        messageID = message.id
        let run = generation
        let preview = preview
        ChatRuntime.shared.registerCleanup(owner: preview, conversationID: context.route.id) { [weak preview] in preview?.close() }
        task = Task { [weak self] in
            await preview.load(message, context: context)
            guard let self, self.generation == run, !Task.isCancelled,
                  ChatRuntime.shared.isCurrent(context), !preview.isInvalidated else { return }
            guard preview.file != nil else {
                if let error = preview.errorMessage { onError(error) }
                return
            }
            do { if try preview.playVoice() { onPlayed() } }
            catch { preview.close(); onError(error.localizedDescription) }
        }
    }

    /// 离页、后台、开录音或打开其他媒体时同步停止，迟到下载不能重开声音。
    func stop() {
        generation = UUID(); task?.cancel(); task = nil
        preview.close(); messageID = nil
    }
}
