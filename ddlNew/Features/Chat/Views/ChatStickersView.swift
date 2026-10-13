//
//  ChatStickersView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import SwiftUI
import Kingfisher

struct ChatStickersView: View {
    @ObservedObject var chat: ChatStore
    @StateObject private var store = ChatStickersStore(client: SDKChatStickersClient())
    @ObservedObject private var connection = OSSConnectionBootstrap.shared

    /// 已用贴纸以完整资源显示动画，发送动作继续沿当前真实SDK合同。
    var body: some View {
        List {
            if let error = store.errorMessage { Text(error).foregroundStyle(.red); Button("重试") { Task { await store.loadMore() } } }
            if store.stickers.isEmpty && !store.busy { Text("暂无已用贴纸或收藏表情").foregroundStyle(.secondary) }
            ForEach(store.stickers) { sticker in
                Button { send(sticker) } label: {
                    HStack {
                        ChatAnimatedRemoteImage(url: RemoteAvatarURL.resolve(sticker.resource.isEmpty ? sticker.thumbnail : sticker.resource, relativeTo: connection.current?.getFileHost), fileHost: connection.current?.getFileHost, size: CGSize(width: 64, height: 64)).accessibilityHidden(true)
                        Text(sticker.title)
                        Spacer()
                        Text("发送").font(.caption)
                    }
                }.disabled(!chat.permission.canSend).accessibilityLabel("发送" + sticker.title)
            }
            if store.hasMore { Button("加载更多") { Task { await store.loadMore() } }.disabled(store.busy) }
            if store.busy { ProgressView() }
        }.navigationTitle("已有贴纸")
        .task { if let context = chat.context { await store.open(context) } }
        .onDisappear { store.close() }
    }
    /// 资源来自已用包，沿真实SDK发送及ACK统一权限与频控。
    private func send(_ sticker: ChatSticker) {
        guard let context = chat.context else { return }
        var message = ChatMessageRecord(localID: UUID().uuidString, conversationID: context.route.id, senderID: context.userUID, senderName: "我", type: 12, timestamp: Int64(Date().timeIntervalSince1970 * 1000))
        message.resource = sticker.resource; message.thumbnail = sticker.thumbnail; message.stickerID = sticker.id; message.isStickerSet = sticker.fromPackage; message.size = sticker.bytes; message.mediaWidth = sticker.width; message.mediaHeight = sticker.height
        do { try chat.sendAttachment(message) } catch { store.errorMessage = error.localizedDescription }
    }
}
