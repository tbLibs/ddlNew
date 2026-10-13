//
//  ChatMediaPreviewStore.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import Combine
import CryptoKit
import AVFoundation

@MainActor final class ChatMediaPreviewStore: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var file: URL?
    @Published private(set) var loading = false
    @Published private(set) var playing = false
    @Published private(set) var isInvalidated = false
    @Published private(set) var usesReceiver = false
    @Published var errorMessage: String?
    private var session: URLSession?
    private var player: AVAudioPlayer?
    private var generation = UUID()
    private var loadedContext: ChatContext?
    private var loadedSenderID: String?
    private var loadedMessageID: String?
    private var loadedServerID: String?
    private var invalidatedMessageID: String?
    private var interruptionObserver: NSObjectProtocol?

    /// 缓存路径包含俱乐部和用户，不从上个用户文件缓存打开附件。
    func load(_ message: ChatMessageRecord, context: ChatContext) async {
        if invalidatedMessageID == message.id || ChatRuntime.shared.isMessageDeleted(message, context: context) { invalidate(message.id); return }
        invalidatedMessageID = nil; isInvalidated = false
        close(); let run = generation
        loadedContext = context; loadedSenderID = message.senderID; loadedMessageID = message.id; loadedServerID = message.serverID
        guard ChatRuntime.shared.isCurrent(context), let host = OSSConnectionBootstrap.shared.current?.getFileHost,
              let resource = RemoteAvatarURL.resolve(message.resource, relativeTo: host) else { errorMessage = "资源地址已不可用"; return }
        loading = true; defer { if generation == run { loading = false } }
        do {
            let identity = SHA256.hash(data: Data((context.tenantID + ":" + context.userUID).utf8)).map { String(format: "%02x", $0) }.joined()
            let messageKey = SHA256.hash(data: Data((message.serverID.isEmpty ? message.localID : message.serverID).utf8)).map { String(format: "%02x", $0) }.joined()
            let conversationKey = SHA256.hash(data: Data(context.route.id.utf8)).map { String(format: "%02x", $0) }.joined()
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ChatMedia").appendingPathComponent(identity).appendingPathComponent(conversationKey).appendingPathComponent(messageKey)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let name = message.fileName.isEmpty ? resource.lastPathComponent : URL(fileURLWithPath: message.fileName).lastPathComponent
            let cached = directory.appendingPathComponent(name.isEmpty ? "附件" : name)
            if FileManager.default.fileExists(atPath: cached.path) { file = cached; return }
            let session = URLSession(configuration: .ephemeral, delegate: ChatTransferSessionDelegate(origin: host), delegateQueue: nil)
            self.session = session; defer { session.finishTasksAndInvalidate() }
            let (temporary, response) = try await session.download(for: URLRequest(url: resource))
            guard !Task.isCancelled, generation == run, ChatRuntime.shared.isCurrent(context) else { return }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw ChatClientError.unavailable("附件已失效或下载失败，请重试") }
            let decoded = try await Task.detached { try LegacyChatMediaCodec.decodeFile(temporary) }.value
            defer { if decoded != temporary { try? FileManager.default.removeItem(at: decoded) } }
            guard generation == run, ChatRuntime.shared.isCurrent(context) else { return }
            try FileManager.default.moveItem(at: decoded, to: cached); file = cached
        } catch { if generation == run, !(error is CancellationError) { errorMessage = "下载失败：" + error.localizedDescription } }
    }

    /// 成员历史删除只停止同身份同会话被删作者的已打开预览，不影响录音草稿。
    func invalidateDeletedMessages(_ ids: Set<String>, context: ChatContext) {
        guard let loadedContext, let loadedSenderID, let loadedMessageID, ids.contains(loadedSenderID),
              loadedContext.userUID == context.userUID, loadedContext.tenantID == context.tenantID, loadedContext.sessionID == context.sessionID,
              loadedContext.route.id == context.route.id else { return }
        invalidate(loadedMessageID)
    }

    /// 单条撤回删除或整段清空只让当前身份、当前聊天匹配的附件失效。
    func invalidateMessage(_ message: ChatMessageRecord?, context: ChatContext) {
        guard let loadedContext, let loadedMessageID,
              loadedContext.userUID == context.userUID, loadedContext.tenantID == context.tenantID,
              loadedContext.sessionID == context.sessionID, loadedContext.route.id == context.route.id else { return }
        if let message, message.id != loadedMessageID && (message.serverID.isEmpty || message.serverID != loadedServerID) { return }
        invalidate(loadedMessageID)
    }

    /// 删除原条后取消网络和播放并保持失效标记，前台恢复也不能重新取旧资源。
    private func invalidate(_ id: String) { close(); invalidatedMessageID = id; isInvalidated = true; errorMessage = "原消息已删除，附件已停止播放或下载" }

    /// 语音文件真正开始播放后才由页面报告已读，下载与可见不算播放。
    func playVoice() throws -> Bool {
        guard let file else { return false }
        let player = try AVAudioPlayer(contentsOf: file); player.delegate = self; self.player = player
        try configureAudio()
        observeInterruption()
        guard player.play() else { throw ChatClientError.unavailable("语音无法播放，请重试") }
        playing = true; return true
    }

    /// 用户切换听筒或扬声器，蓝牙耳机仍由系统音频路由决定。
    func setReceiver(_ value: Bool) throws { usesReceiver = value; if playing { try configureAudio() } }

    /// 仅实际播放启用音频会话，停止后让系统恢复其他声音。
    private func configureAudio() throws {
        let session = AVAudioSession.sharedInstance()
        if usesReceiver { try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP]); try session.overrideOutputAudioPort(.none) }
        else { try session.setCategory(.playback, mode: .spokenAudio) }
        try session.setActive(true)
    }

    /// 电话和其他系统中断立即停播，未播放过的语音不伪造已读。
    private func observeInterruption() {
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        let run = generation
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let began = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue == AVAudioSession.InterruptionType.began.rawValue
            guard began, let owner = self else { return }
            Task { @MainActor in guard owner.generation == run else { return }; owner.player?.stop(); owner.playing = false }
        }
    }

    /// 实际播放结束更新按钮状态，回调不得延长页面生命周期。
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in guard self.player === player else { return }; self.playing = false; try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }

    /// 指定聊天清缓存，路径包含用户、俱乐部与会话，不能清其他聊天资源。
    static func clearCache(context: ChatContext) throws {
        let identity = SHA256.hash(data: Data((context.tenantID + ":" + context.userUID).utf8)).map { String(format: "%02x", $0) }.joined()
        let conversation = SHA256.hash(data: Data(context.route.id.utf8)).map { String(format: "%02x", $0) }.joined()
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ChatMedia").appendingPathComponent(identity).appendingPathComponent(conversation)
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }

    /// 离页停止播放和网络；保留原条归属，以便后台期间删除仍能阻止回前台下载。
    func close() {
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }; interruptionObserver = nil
        if playing { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        generation = UUID(); session?.invalidateAndCancel(); session = nil; player?.stop(); player = nil; file = nil; playing = false; loading = false; errorMessage = nil }
}
