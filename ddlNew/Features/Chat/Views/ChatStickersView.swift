//
//  ChatStickersView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import SwiftUI
import UIAdapter
import Kingfisher

struct ChatStickersView: View {
    @ObservedObject var chat: ChatStore
    var embedded = false
    @StateObject private var store = ChatStickersStore(client: SDKChatStickersClient())
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    @State private var sentFeedback: String?
    @State private var sendError: String?
    @Environment(\.dismiss) private var dismiss

    /// 内嵌面板和独立页面共用真实贴纸内容，不重复提供两个发送入口。
    private var pickerContent: some View {
        MessagingScroll {
            VStack(alignment: .leading, spacing: 16.zoom()) {
                if !embedded { Text("选择表情发送到当前聊天").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText) }
                if !chat.permission.canSend { Text("当前聊天暂不能发送消息").foregroundStyle(MessagingTheme.error).font(.subheadline) }
                if store.errorMessage != nil { Button("重试") { Task { await store.loadMore() } }.frame(minHeight: 44).disabled(store.busy) }
                if store.stickers.isEmpty && !store.busy && store.errorMessage == nil { Label("暂无已用贴纸或收藏表情", systemImage: "face.smiling").foregroundStyle(MessagingTheme.secondaryText).padding(.vertical, 32.zoom()) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: (embedded ? 64.0 : 92.0).zoom()), spacing: 12.zoom())], spacing: 16.zoom()) {
                    ForEach(store.stickers) { sticker in
                        Button { send(sticker) } label: {
                            VStack(spacing: 8.zoom()) {
                                ChatAnimatedRemoteImage(url: RemoteAvatarURL.resolve(sticker.resource.isEmpty ? sticker.thumbnail : sticker.resource, relativeTo: connection.current?.getFileHost), fileHost: connection.current?.getFileHost, size: CGSize(width: 72.zoom(), height: 72.zoom())).accessibilityHidden(true)
                                Text(sticker.title.isEmpty ? "贴纸" : sticker.title).font(.caption).lineLimit(2).foregroundStyle(MessagingTheme.text)
                            }.frame(maxWidth: .infinity, minHeight: max(44, 112.zoom())).padding(8.zoom()).contentShape(Rectangle())
                        }.buttonStyle(MessagingRowStyle()).clipShape(RoundedRectangle(cornerRadius: 8.zoom())).disabled(!chat.permission.canSend).accessibilityLabel("发送" + (sticker.title.isEmpty ? "贴纸" : sticker.title))
                    }
                }
                if store.hasMore && !store.busy { Button("加载更多") { Task { await store.loadMore() } }.frame(maxWidth: .infinity, minHeight: max(44, 44.zoom())) }
            }.padding(16.zoom())
        }
    }

    /// 已用贴纸以完整资源显示动画，展开面板仍保留原SDK和身份轮次校验。
    var body: some View {
        Group {
            if embedded { pickerContent }
            else {
                pickerContent.navigationTitle("贴纸与表情").modifier(MessagingPageChrome())
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.frame(minHeight: 44) } }
            }
        }
        .messagingFeedbackToast(store.errorMessage ?? sendError ?? sentFeedback)
        .messagingLoadingToast(!embedded && store.busy, title: "正在加载表情")
        .task { if let context = chat.context { await store.open(context) } }
        .onDisappear { store.close() }
    }
    /// 资源来自已用包，沿真实SDK发送及ACK统一权限与频控。
    private func send(_ sticker: ChatSticker) {
        guard let context = chat.context else { return }
        var message = ChatMessageRecord(localID: UUID().uuidString, conversationID: context.route.id, senderID: context.userUID, senderName: "我", type: 12, timestamp: Int64(Date().timeIntervalSince1970 * 1000))
        message.resource = sticker.resource; message.thumbnail = sticker.thumbnail; message.stickerID = sticker.id; message.isStickerSet = sticker.fromPackage; message.size = sticker.bytes; message.mediaWidth = sticker.width; message.mediaHeight = sticker.height
        do { try chat.sendAttachment(message); sendError = nil; sentFeedback = "已加入发送队列，等待消息回执" } catch { sentFeedback = nil; sendError = error.localizedDescription }
    }
}
