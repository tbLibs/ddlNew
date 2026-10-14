//
//  ChatMessageBubble.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter
import Kingfisher

struct ChatMessageBubble: View {
    let message: ChatMessageRecord
    let own: Bool
    let isSelected: Bool
    let isHighlighted: Bool
    let onRetry: () -> Void
    var onReference: () -> Void = {}
    var onAvatar: (() -> Void)? = nil
    var onMention: (() -> Void)? = nil
    var referenceSummary: String = "引用原文尚未加载，点击定位"
    @ObservedObject private var connection = OSSConnectionBootstrap.shared

    var body: some View {
        HStack(alignment: .top, spacing: 10.zoom()) {
            if own { Spacer(minLength: 36) }
            if !own { avatar }
            VStack(alignment: own ? .trailing : .leading, spacing: 5.zoom()) {
                if !own && !message.senderName.isEmpty { Text(message.senderName).font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
                content
                    .padding(12.zoom())
                    .background(own ? MessagingTheme.outgoingBubble : MessagingTheme.surface)
                    .foregroundStyle(own ? Color.white : MessagingTheme.text)
                    .clipShape(RoundedRectangle(cornerRadius: 10.zoom()))
                    .overlay(RoundedRectangle(cornerRadius: 10.zoom()).stroke(isHighlighted ? Color.orange : .clear, lineWidth: 2))
                HStack(spacing: 8.zoom()) {
                    Text(Date(timeIntervalSince1970: Double(message.timestamp) / 1000), style: .time).font(.caption2).foregroundStyle(MessagingTheme.secondaryText)
                    if own && message.status == .normal {
                        switch message.state {
                        case .sending: ProgressView().controlSize(.mini).accessibilityLabel("发送中")
                        case .failed: Button("发送失败，重试", action: onRetry).font(.caption).foregroundStyle(MessagingTheme.error).frame(minWidth: max(44, 44.zoom()), minHeight: max(44, 44.zoom()))
                        case .sent:
                            if UserRoleAuthorityStore.shared.current?.allows("showUserRead") == true && message.totalReadCount > 0 { Text("\(message.readCount)/\(message.totalReadCount)已读").font(.caption2).foregroundStyle(MessagingTheme.secondaryText) }
                        }
                    }
                }
                if let failure = message.failure, message.state == .failed { Text(failure.message).font(.caption).foregroundStyle(MessagingTheme.error) }
            }
            if own { avatar }
            if !own { Spacer(minLength: 36) }
            if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(MessagingTheme.accent).accessibilityLabel("已选择") }
        }
        .accessibilityElement(children: .contain)
    }

    /// 头像使用显式按钮提供资料入口，辅助功能不依赖点击手势。
    @ViewBuilder private var avatar: some View {
        if let onAvatar {
            Button(action: onAvatar) { avatarImage.frame(minWidth: max(44, 44.zoom()), minHeight: max(44, 44.zoom())).contentShape(Rectangle()) }.buttonStyle(.plain)
                .accessibilityLabel("查看" + (message.senderName.isEmpty ? "用户" : message.senderName) + "资料")
                .contextMenu { if let onMention { Button("提及 " + message.senderName, action: onMention) } }
                .accessibilityActions { if let onMention { Button("提及 " + message.senderName, action: onMention) } }
        } else { avatarImage }
    }

    private var avatarImage: some View {
        KFImage(RemoteAvatarURL.resolve(message.avatarURL, relativeTo: connection.current?.getFileHost))
            .setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: 68.zoom(), height: 68.zoom())))
            .downloader(NetworkImageDownloader.downloader(for: connection.current?.getFileHost))
            .placeholder { Image(systemName: "person.crop.circle.fill").foregroundStyle(MessagingTheme.secondaryText) }
            .resizable().scaledToFill().frame(width: 40.zoom(), height: 40.zoom()).clipShape(Circle()).accessibilityHidden(true)
    }

    /// 仅显示系统识别的HTTP链接，必须用户点击才访问且不保存未批准链接收藏。
    private var messageLinks: [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        return detector.matches(in: message.text, range: NSRange(location: 0, length: message.text.utf16.count)).compactMap { $0.url }.filter { ["https", "http"].contains($0.scheme?.lowercased() ?? "") }
    }

    /// 动图使用原资源保留帧，照片与视频封面仍先解码再按展示尺寸采样。
    @ViewBuilder private var content: some View {
        if !message.isCompatible { Text(message.displayText).foregroundStyle(own ? Color.white : MessagingTheme.secondaryText) }
        else if message.status == .recalled { Text("消息已撤回").font(.callout).italic() }
        else {
            if !message.referenceID.isEmpty { Button(action: onReference) { Label(referenceSummary, systemImage: "arrowshape.turn.up.left").font(.caption).foregroundStyle(own ? Color.white : MessagingTheme.secondaryText).frame(minHeight: max(44, 44.zoom())) }.accessibilityLabel("定位引用消息") }
            if isAnimatedResource {
                ChatAnimatedRemoteImage(url: RemoteAvatarURL.resolve(message.resource.isEmpty ? message.thumbnail : message.resource, relativeTo: connection.current?.getFileHost), fileHost: connection.current?.getFileHost, size: CGSize(width: 220.zoom(), height: 200.zoom()))
                    .accessibilityLabel(message.type == 12 ? "贴纸" : "动态图片")
            } else if [1, 2, 12].contains(message.type), let url = RemoteAvatarURL.resolve(message.thumbnail.isEmpty ? message.resource : message.thumbnail, relativeTo: connection.current?.getFileHost) {
                KFImage(url).setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: 440.zoom(), height: 400.zoom()))).downloader(NetworkImageDownloader.downloader(for: connection.current?.getFileHost))
                    .placeholder { ProgressView() }.resizable().scaledToFit().frame(maxWidth: 220, maxHeight: 200)
                if message.type == 2 { Label("视频", systemImage: "play.circle.fill") }
            } else { Text(message.displayText).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
            if [0, 10].contains(message.type) { ForEach(messageLinks, id: \.absoluteString) { url in Link("打开链接：" + (url.host ?? url.absoluteString), destination: url).tint(own ? Color.white : MessagingTheme.accent).frame(minHeight: max(44, 44.zoom())).accessibilityLabel("打开链接 " + url.absoluteString) } }
        }
    }

    /// 贴纸协议可能没有GIF扩展名，普通照片只在真实URL标明GIF时启用动画。
    private var isAnimatedResource: Bool {
        guard message.status == .normal else { return false }
        if message.type == 12 { return true }
        guard message.type == 1 else { return false }
        return [message.resource, message.thumbnail].contains { URL(string: $0)?.pathExtension.lowercased() == "gif" }
    }
}
