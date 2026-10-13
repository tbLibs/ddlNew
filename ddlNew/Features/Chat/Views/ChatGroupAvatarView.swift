//
//  ChatGroupAvatarView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import SwiftUI
import PhotosUI
import Kingfisher

struct ChatGroupAvatarView: View {
    let route: ChatRoute
    @ObservedObject var store: ChatSettingsStore
    @State private var photo: PhotosPickerItem?
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var progress = 0.0
    @State private var client = SDKChatMediaClient()
    @State private var preparation: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 24) {
            KFImage(RemoteAvatarURL.resolve(store.snapshot?.group?.avatar ?? route.avatarURL, relativeTo: OSSConnectionBootstrap.shared.current?.getFileHost))
                .setProcessor(LegacyRemoteImageProcessor()).resizable().scaledToFit().frame(maxWidth: 280, maxHeight: 280).accessibilityLabel("当前群头像")
            if let error = errorMessage ?? store.errorMessage { Text(error).foregroundStyle(.red) }
            if busy { ProgressView(value: progress); Button("取消上传") { preparation?.cancel(); client.cancel(); busy = false } }
            if [1, 2].contains(store.snapshot?.group?.role ?? 0) {
                PhotosPicker(selection: $photo, matching: .images) { Label("选择新群头像", systemImage: "photo").frame(minHeight: 44) }.disabled(busy || store.busy)
            }
        }.padding().navigationTitle("群头像")
        .onChange(of: photo) { item in preparation?.cancel(); preparation = Task { await upload(item) } }
        .onDisappear { preparation?.cancel(); client.cancel() }
    }

    /// 上传前和保存前各刷新群身份，失败保留原头像且不产生聊天消息。
    private func upload(_ item: PhotosPickerItem?) async {
        guard let item, let context = ChatRuntime.shared.context(for: route), !busy else { return }
        ChatRuntime.shared.registerCleanup(owner: client, conversationID: route.id) { [weak client] in client?.cancel() }
        busy = true; errorMessage = nil; progress = 0; defer { busy = false; photo = nil }
        await store.reload()
        guard [1, 2].contains(store.snapshot?.group?.role ?? 0), store.snapshot?.group?.isActive == true else { errorMessage = "群头像编辑权限已变化"; return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), !Task.isCancelled else { return }
            let prepared = try await Task.detached { try ChatAttachmentPreparation.image(data) }.value
            defer { try? FileManager.default.removeItem(at: prepared.file) }
            let attachment = ChatAttachment(file: prepared.file, type: 101, name: prepared.name, bytes: prepared.bytes)
            let result = try await client.upload(attachment, context: context) { progress = $0 }
            guard !Task.isCancelled, ChatRuntime.shared.isCurrent(context) else { return }
            _ = await store.groupAction(.avatar(result.resource))
        } catch { if !(error is CancellationError) { errorMessage = error.localizedDescription } }
    }
}
