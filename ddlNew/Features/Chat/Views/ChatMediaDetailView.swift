//
//  ChatMediaDetailView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import AVKit

struct ChatMediaDetailView: View {
    let message: ChatMessageRecord
    let context: ChatContext
    var allowSharing = true
    let onVoicePlayed: () -> Void
    @StateObject private var store = ChatRuntime.shared.makePreviewStore()
    @State private var videoPlayer: AVPlayer?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 16) {
            if store.loading { ProgressView("正在下载附件") }
            if let error = store.errorMessage { Text(error).foregroundStyle(.red); if !store.isInvalidated { Button("重试下载") { Task { await store.load(message, context: context) } } } }
            if let file = store.file {
                if message.type == 2 { VideoPlayer(player: videoPlayer).onAppear { if videoPlayer == nil { videoPlayer = AVPlayer(url: file) } } }
                else if message.type == 4 {
                    Text("语音 \(Int(message.duration))秒")
                    Toggle("听筒播放", isOn: Binding(get: { store.usesReceiver }, set: { value in do { try store.setReceiver(value) } catch { store.errorMessage = error.localizedDescription } })).padding()
                    Button(store.playing ? "重新播放" : "播放语音") { do { if try store.playVoice() { onVoicePlayed() } } catch { store.errorMessage = error.localizedDescription } }.frame(minWidth: 44, minHeight: 44)
                } else { ChatFilePreview(file: file) }
                if allowSharing { ShareLink(item: file) { Label("分享或系统打开", systemImage: "square.and.arrow.up") }.padding() }
            }
        }
        .navigationTitle(message.fileName.isEmpty ? "消息附件" : message.fileName)
        .task { registerCleanup(); await store.load(message, context: context) }
        .onDisappear { videoPlayer?.pause(); videoPlayer = nil; store.close() }
        .onChange(of: store.isInvalidated) { invalidated in if invalidated { videoPlayer?.pause(); videoPlayer = nil } }
        .onChange(of: scenePhase) { phase in
            if phase != .active { videoPlayer?.pause(); videoPlayer = nil; store.close() }
            else if ChatRuntime.shared.isCurrent(context), store.file == nil, !store.loading, !store.isInvalidated { Task { await store.load(message, context: context) } }
        }
    }
    /// 弱下载所有者供根会话取消，独立于SwiftUI task的强页面捕获。
    private func registerCleanup() { let preview = store; ChatRuntime.shared.registerCleanup(owner: preview, conversationID: context.route.id) { [weak preview] in preview?.close() } }
}
