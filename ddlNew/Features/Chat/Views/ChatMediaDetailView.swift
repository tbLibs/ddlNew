//
//  ChatMediaDetailView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

struct ChatMediaDetailView: View {
    let message: ChatMessageRecord
    let context: ChatContext
    var allowSharing = true
    let onVoicePlayed: () -> Void
    @StateObject private var store = ChatRuntime.shared.makePreviewStore()
    @State private var requestedDownload = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            if store.loading {
                Spacer()
                Text(attachmentName).font(.subheadline).foregroundStyle(MessagingTheme.secondaryText).multilineTextAlignment(.center).padding(.horizontal, 24.zoom())
                if message.type == 5 { Button("取消下载") { requestedDownload = false; store.close() }.frame(minHeight: max(44, 44.zoom())).padding(16.zoom()) }
                Spacer()
            }
            if message.type == 5 && store.file == nil && !store.loading && store.errorMessage == nil {
                Spacer()
                VStack(spacing: 16.zoom()) {
                    Image(systemName: "doc.fill").font(.system(size: 64.zoom())).foregroundStyle(MessagingTheme.accent).accessibilityHidden(true)
                    Text(attachmentName).font(.headline).multilineTextAlignment(.center)
                    if message.size > 0 { Text(ByteCountFormatter.string(fromByteCount: message.size, countStyle: .file)).font(.subheadline).foregroundStyle(MessagingTheme.secondaryText) }
                    Button("下载并预览") { requestedDownload = true; Task { await store.load(message, context: context) } }.buttonStyle(MessagingActionButtonStyle(fullWidth: true))
                }.frame(maxWidth: 400).padding(24.zoom())
                Spacer()
            }
            if store.errorMessage != nil {
                VStack(spacing: 12.zoom()) {
                    if !store.isInvalidated { Button("重试下载") { Task { await store.load(message, context: context) } }.buttonStyle(MessagingActionButtonStyle(fill: MessagingTheme.surface, foreground: MessagingTheme.accent, border: MessagingTheme.border)).disabled(store.loading) }
                }.padding(24.zoom())
            }
            if let file = store.file {
                if message.type == 4 {
                    MessagingScroll {
                        VStack(spacing: 24.zoom()) {
                            Image(systemName: store.playing ? "waveform" : "speaker.wave.2").font(.system(size: 48.zoom())).foregroundStyle(MessagingTheme.accent).accessibilityHidden(true)
                            Text("语音 \(Int(message.duration)) 秒").font(.title3.weight(.semibold))
                            Text(store.playing ? "正在播放" : "点击播放语音").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                            MessagingCard {
                                Toggle("听筒播放", isOn: Binding(get: { store.usesReceiver }, set: { value in do { try store.setReceiver(value) } catch { store.errorMessage = error.localizedDescription } })).frame(minHeight: max(44, 44.zoom()))
                            }
                            Button(store.playing ? "重新播放" : "播放语音") { do { if try store.playVoice() { onVoicePlayed() } } catch { store.errorMessage = error.localizedDescription } }
                                .buttonStyle(MessagingActionButtonStyle(fullWidth: true))
                        }.padding(24.zoom())
                    }
                } else if message.type == 5 {
                    HStack(spacing: 12.zoom()) {
                        Image(systemName: "doc.fill").font(.title).foregroundStyle(MessagingTheme.accent).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4.zoom()) {
                            Text(attachmentName).font(.body.weight(.semibold))
                            if message.size > 0 { Text(ByteCountFormatter.string(fromByteCount: message.size, countStyle: .file)).font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(16.zoom()).background(MessagingTheme.surface)
                    ChatFilePreview(file: file)
                }
                if allowSharing {
                    ShareLink(item: file) { Label("其他应用打开或分享", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                        .buttonStyle(MessagingActionButtonStyle(fill: MessagingTheme.surface, foreground: MessagingTheme.accent, border: MessagingTheme.border)).padding(16.zoom()).background(MessagingTheme.surface)
                }
            }
            if store.file == nil && !store.loading { Spacer(minLength: 0) }
        }
        .navigationTitle(attachmentName).modifier(MessagingPageChrome())
        .messagingLoadingToast(store.loading, title: "正在下载附件")
        .messagingFeedbackToast(store.errorMessage)
        .task { registerCleanup(); if message.type == 4 { await store.load(message, context: context) } }
        .onDisappear { store.close() }
        .onChange(of: scenePhase) { phase in
            if phase != .active { store.close() }
            else if (message.type == 4 || requestedDownload), ChatRuntime.shared.isCurrent(context), store.file == nil, !store.loading, !store.isInvalidated { Task { await store.load(message, context: context) } }
        }
    }
    private var attachmentName: String { if !message.fileName.isEmpty { return message.fileName }; return message.type == 4 ? "语音" : "消息附件" }
    /// 弱下载所有者供根会话取消，独立于 SwiftUI task 的强页面捕获。
    private func registerCleanup() { let preview = store; ChatRuntime.shared.registerCleanup(owner: preview, conversationID: context.route.id) { [weak preview] in preview?.close() } }
}
