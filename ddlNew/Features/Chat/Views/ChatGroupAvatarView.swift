//
//  ChatGroupAvatarView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import SwiftUI
import PhotosUI
import Kingfisher
import UIAdapter

struct ChatGroupAvatarView: View {
    let route: ChatRoute
    @ObservedObject var store: ChatSettingsStore
    @State private var photo: PhotosPickerItem?
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var progress = 0.0
    @State private var feedback: String?
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    @State private var client = SDKChatMediaClient()
    @State private var preparation: Task<Void, Never>?

    var body: some View {
        MessagingScroll {
            VStack(spacing: 24.zoom()) {
                MessagingCard {
                    KFImage(RemoteAvatarURL.resolve(store.snapshot?.group?.avatar ?? route.avatarURL, relativeTo: connection.current?.getFileHost))
                        .downloader(NetworkImageDownloader.downloader(for: connection.current?.getFileHost))
                        .setProcessor(LegacyRemoteImageProcessor())
                        .placeholder { Image(systemName: "person.3.fill").font(.largeTitle).foregroundStyle(MessagingTheme.secondaryText).frame(width: 240.zoom(), height: 240.zoom()).background(MessagingTheme.avatarBackground) }
                        .resizable().scaledToFit().frame(maxWidth: 280.zoom(), maxHeight: 280.zoom())
                        .clipShape(RoundedRectangle(cornerRadius: 12.zoom())).frame(maxWidth: .infinity).accessibilityLabel("当前群头像")
                }
                if let error = errorMessage ?? store.errorMessage { Text(error).font(.subheadline).foregroundStyle(MessagingTheme.error).frame(maxWidth: .infinity, alignment: .leading) }
                if let feedback { Text(feedback).font(.subheadline).foregroundStyle(MessagingTheme.accent) }
                if busy {
                    VStack(spacing: 12.zoom()) {
                        ProgressView(value: progress).tint(MessagingTheme.accent)
                        Text(progress == 0 ? "正在准备图片" : "正在上传群头像 \(Int(progress * 100))%").font(.footnote).foregroundStyle(MessagingTheme.secondaryText)
                        Button("取消上传") { preparation?.cancel(); client.cancel() }.frame(minHeight: 44)
                    }
                }
                if [1, 2].contains(store.snapshot?.group?.role ?? 0) {
                    PhotosPicker(selection: $photo, matching: .images) { Label("选择新群头像", systemImage: "photo").frame(maxWidth: .infinity, minHeight: max(44, 48.zoom())) }
                        .buttonStyle(.borderedProminent).tint(MessagingTheme.primaryAction).disabled(busy || store.busy)
                }
            }.padding(16.zoom())
        }.navigationTitle("群头像").modifier(MessagingPageChrome())
        .onChange(of: photo) { item in preparation?.cancel(); preparation = Task { await upload(item) } }
        .onDisappear { preparation?.cancel(); client.cancel() }
    }

    /// 上传前和保存前各刷新群身份，失败保留原头像且不产生聊天消息。
    private func upload(_ item: PhotosPickerItem?) async {
        guard let item, let context = ChatRuntime.shared.context(for: route), !busy else { return }
        ChatRuntime.shared.registerCleanup(owner: client, conversationID: route.id) { [weak client] in client?.cancel() }
        busy = true; errorMessage = nil; feedback = nil; progress = 0; defer { busy = false; photo = nil }
        await store.reload()
        guard [1, 2].contains(store.snapshot?.group?.role ?? 0), store.snapshot?.group?.isActive == true else { errorMessage = "群头像编辑权限已变化"; return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), !Task.isCancelled else { return }
            let prepared = try await Task.detached { try ChatAttachmentPreparation.image(data) }.value
            defer { try? FileManager.default.removeItem(at: prepared.file) }
            let attachment = ChatAttachment(file: prepared.file, type: 101, name: prepared.name, bytes: prepared.bytes)
            let result = try await client.upload(attachment, context: context) { progress = $0 }
            guard !Task.isCancelled, ChatRuntime.shared.isCurrent(context) else { return }
            if await store.groupAction(.avatar(result.resource)), store.errorMessage == nil { feedback = "群头像已更新" }
        } catch { if !(error is CancellationError) { errorMessage = error.localizedDescription } }
    }
}
