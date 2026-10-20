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
    var showsSenderName = false
    var scrollVisibility: ChatScrollGeometry?
    var onGameAnimationComplete: (ChatMessageRecord) -> Void = { _ in }
    var voicePlayback: ChatVoicePlayback? = nil
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    @ObservedObject private var session = UserSessionStore.shared

    var body: some View {
        HStack(alignment: .top, spacing: 6.zoom()) {
            if own { Spacer(minLength: 36) }
            if !own { avatar }
            VStack(alignment: own ? .trailing : .leading, spacing: 5.zoom()) {
                if showsSenderName && !own && !message.senderName.isEmpty { Text(message.senderName).font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
                content
                    .padding(isVisualMedia ? 0 : 10.zoom())
                    .background(isVisualMedia ? Color.clear : own ? MessagingTheme.outgoingBubble : MessagingTheme.surface)
                    .foregroundStyle(isVisualMedia ? MessagingTheme.text : own ? MessagingTheme.onPrimaryAction : MessagingTheme.text)
                    .clipShape(ChatMediaBubbleShape(own: own, media: isVisualMedia))
                    // 本人气泡用反差内框并留出绿色外沿，避免白框与浅色页面连成一片。
                    .overlay {
                        if isHighlighted {
                            if isVisualMedia {
                                ChatMediaBubbleShape(own: own).stroke(MessagingTheme.accent, lineWidth: 3)
                            } else {
                                RoundedRectangle(cornerRadius: 8.zoom()).inset(by: own ? 2 : 0)
                                    .strokeBorder(own ? MessagingTheme.onPrimaryAction : MessagingTheme.accent, lineWidth: 3)
                            }
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if showsReadProgress {
                            readProgressView.offset(x: -22.zoom()).allowsHitTesting(false)
                        }
                    }
                    .overlay(alignment: .leading) {
                        if own && isVisualMedia && message.state == .sending {
                            ProgressView().controlSize(.mini).frame(width: 16.zoom(), height: 16.zoom())
                                .offset(x: -22.zoom()).accessibilityLabel(message.isMediaUploading ? "上传中" : "发送中")
                        }
                    }
                    .overlay(alignment: .trailing) {
                        if !own && message.type == 4 && message.status == .normal && !message.isRead {
                            Circle().fill(MessagingTheme.error).frame(width: 6.zoom(), height: 6.zoom())
                                .offset(x: 15.zoom()).accessibilityLabel("语音未读")
                        }
                    }
                HStack(spacing: 8.zoom()) {
                    Text(Date(timeIntervalSince1970: Double(message.timestamp) / 1000), style: .time).font(.caption2).foregroundStyle(MessagingTheme.secondaryText)
                    if own && message.status == .normal {
                        switch message.state {
                        case .sending: if !isVisualMedia { ProgressView().controlSize(.mini).accessibilityLabel("发送中") }
                        case .failed: Button(action: onRetry) { Image(systemName: "exclamationmark.circle.fill").foregroundStyle(MessagingTheme.error).frame(minWidth: max(44, 44.zoom()), minHeight: max(44, 44.zoom())) }.accessibilityLabel("发送失败，重试")
                        case .sent: EmptyView()
                        }
                    }
                }
            }
            if own { avatar }
            if !own { Spacer(minLength: 36) }
        }
        .accessibilityElement(children: .contain)
    }

    /// 图片和贴纸沿旧端直接展示资源，不给整张媒体再加一层文字气泡留白。
    private var isVisualMedia: Bool { message.status == .normal && message.isCompatible && ([1, 2, 12].contains(message.type) || message.type == 21 && ChatGameSticker(rawValue: message.gameType)?.isValid(message.text) == true) && message.referenceID.isEmpty }

    /// 旧端只在本人发送成功且有展示权限时，于气泡左下侧显示16点已读进度。
    private var showsReadProgress: Bool {
        own && message.status == .normal && message.state == .sent && message.type != 20
            && UserRoleAuthorityStore.shared.current?.allows("showUserRead") == true
    }

    private var readProgress: CGFloat {
        guard message.totalReadCount > 0 else { return 0 }
        return CGFloat(min(max(message.readCount, 0), message.totalReadCount)) / CGFloat(message.totalReadCount)
    }

    @ViewBuilder private var readProgressView: some View {
        let progress = readProgress
        ZStack {
            if progress <= 0 {
                Image("img_msg_not_readed").resizable().renderingMode(.template)
                    .foregroundStyle(MessagingTheme.secondaryText)
            } else if progress >= 1 {
                Image("img_msg_all_readed").resizable().renderingMode(.template)
                    .foregroundStyle(MessagingTheme.accent)
            } else {
                Circle().strokeBorder(MessagingTheme.accent, lineWidth: 1.5)
                ChatReadPie(progress: progress).fill(MessagingTheme.accent).padding(2.5)
            }
        }
        .frame(width: 16.zoom(), height: 16.zoom())
        .accessibilityLabel(progress <= 0 ? "未读" : progress >= 1 ? "已读" : "已读\(message.readCount)/\(message.totalReadCount)")
    }

    /// 历史时长来自服务器，非法数值不直接转Int以免破坏整个消息列表。
    private var voiceDuration: String { message.duration.isFinite && message.duration >= 0 ? "\(Int(min(message.duration.rounded(.up), 86_400)))秒" : "时长未知" }

    /// 头像使用显式按钮提供资料入口，辅助功能不依赖点击手势。
    @ViewBuilder private var avatar: some View {
        if let onAvatar {
            Button(action: onAvatar) { avatarImage.frame(minWidth: max(44, 44.zoom()), minHeight: max(44, 44.zoom())).contentShape(Rectangle()) }.buttonStyle(.plain)
                .accessibilityLabel("查看" + (message.senderName.isEmpty ? "用户" : message.senderName) + "资料")
                .contextMenu { if let onMention { Button("提及 " + message.senderName, action: onMention) } }
                .accessibilityActions { if let onMention { Button("提及 " + message.senderName, action: onMention) } }
        } else { avatarImage }
    }

    /// 本人头像沿旧端读取当前资料，覆盖发送中尚未补齐头像的快照及旧历史头像。
    private var avatarResource: String {
        if own, let user = session.currentUser, user.userUID == message.senderID { return user.avatar }
        return message.avatarURL
    }

    private var avatarImage: some View {
        KFImage(RemoteAvatarURL.resolve(avatarResource, relativeTo: connection.current?.getFileHost))
            .setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: 68.zoom(), height: 68.zoom())))
            .downloader(NetworkImageDownloader.downloader(for: connection.current?.getFileHost))
            // 无头像时沿用消息列表单聊头像的图标、强调色和底色。
            .placeholder {
                Image(systemName: "person.fill")
                    .font(.system(size: 18.zoom(), weight: .medium))
                    .foregroundColor(MessagingTheme.accent)
                    .frame(width: 40.zoom(), height: 40.zoom())
                    .background(MessagingTheme.avatarBackground)
            }
            .resizable().scaledToFill().frame(width: 40.zoom(), height: 40.zoom()).clipShape(Circle())
            .overlay(Circle().stroke(MessagingTheme.border, lineWidth: 1))
            .accessibilityHidden(true)
    }

    /// 仅显示系统识别的HTTP链接，必须用户点击才访问且不保存未批准链接收藏。
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    private var messageLinks: [URL] {
        guard let detector = Self.linkDetector else { return [] }
        return detector.matches(in: message.text, range: NSRange(location: 0, length: message.text.utf16.count)).compactMap { $0.url }.filter { ["https", "http"].contains($0.scheme?.lowercased() ?? "") }
    }

    /// 动图使用原资源保留帧，照片与视频封面仍先解码再按展示尺寸采样。
    @ViewBuilder private var content: some View {
        if !message.isCompatible { Text(message.displayText).foregroundStyle(own ? MessagingTheme.onPrimaryAction : MessagingTheme.secondaryText) }
        else if message.status == .recalled { Text("消息已撤回").font(.callout).italic() }
        else {
            if !message.referenceID.isEmpty { Button(action: onReference) { Label(referenceSummary, systemImage: "arrowshape.turn.up.left").font(.caption).foregroundStyle(own ? MessagingTheme.onPrimaryAction : MessagingTheme.secondaryText).frame(minHeight: max(44, 44.zoom())) }.accessibilityLabel("定位引用消息") }
            if message.type == 21 {
                if let scrollVisibility {
                    ChatVisibleGameStickerBubble(message: message, onComplete: onGameAnimationComplete, visibility: scrollVisibility)
                } else {
                    ChatGameStickerBubble(message: message, onComplete: onGameAnimationComplete, canAnimate: false)
                }
            } else if isAnimatedResource {
                ChatAnimatedRemoteImage(url: RemoteAvatarURL.resolve(message.resource.isEmpty ? message.thumbnail : message.resource, relativeTo: connection.current?.getFileHost), fileHost: connection.current?.getFileHost,
                                        size: message.type == 1 ? mediaSize : CGSize(width: 220.zoom(), height: 200.zoom()))
                    .clipShape(ChatMediaBubbleShape(own: own))
                    .accessibilityLabel(message.type == 12 ? "贴纸" : "动态图片")
            } else if [1, 2].contains(message.type) {
                mediaContent
            } else if message.type == 12, let url = RemoteAvatarURL.resolve(message.thumbnail.isEmpty ? message.resource : message.thumbnail, relativeTo: connection.current?.getFileHost) {
                KFImage(url).setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: 440.zoom(), height: 400.zoom()))).downloader(NetworkImageDownloader.downloader(for: connection.current?.getFileHost))
                    .placeholder { ProgressView() }.resizable().scaledToFit().frame(maxWidth: 220.zoom(), maxHeight: 200.zoom())
            } else if message.type == 4 {
                if let voicePlayback {
                    ChatVoiceMessageContent(message: message, own: own, playback: voicePlayback)
                } else {
                    Label(voiceDuration, systemImage: "play.fill").font(.body)
                }
            } else if message.type == 5 {
                HStack(spacing: 12.zoom()) {
                    Image(systemName: "doc.fill").font(.system(size: 32.zoom()))
                    VStack(alignment: .leading, spacing: 6.zoom()) {
                        Text(message.fileName.isEmpty ? "文件" : message.fileName).font(.subheadline).lineLimit(2)
                        Text(ByteCountFormatter.string(fromByteCount: message.size, countStyle: .file)).font(.caption).opacity(0.8)
                    }
                }.frame(maxWidth: 220.zoom(), alignment: .leading)
            } else { ChatEmojiText(value: message.displayText).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
            if [0, 10].contains(message.type) { ForEach(messageLinks, id: \.absoluteString) { url in Link("打开链接：" + (url.host ?? url.absoluteString), destination: url).tint(own ? MessagingTheme.onPrimaryAction : MessagingTheme.accent).frame(minHeight: max(44, 44.zoom())).accessibilityLabel("打开链接 " + url.absoluteString) } }
        }
    }

    /// 本地预览与远端封面共用旧端170点长边和视频覆盖层，上传结束只换图片源。
    private var mediaContent: some View {
        let size = mediaSize
        let url = message.localMediaPreviewURL ?? RemoteAvatarURL.resolve(
            message.thumbnail.isEmpty ? message.resource : message.thumbnail,
            relativeTo: connection.current?.getFileHost)
        return ZStack {
            MessagingTheme.avatarBackground
            if let url {
                KFImage(url)
                    .setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: 340.zoom(), height: 340.zoom())))
                    .downloader(NetworkImageDownloader.downloader(for: connection.current?.getFileHost))
                    .resizable().scaledToFill().frame(width: size.width, height: size.height).clipped()
            }
            if message.type == 2 {
                Image("icon_video_msg_play").resizable().frame(width: 44.zoom(), height: 44.zoom())
                HStack(spacing: 6.zoom()) {
                    Image("img_video_msg_sign").resizable().frame(width: 18.zoom(), height: 14.zoom())
                    Text(videoDuration).font(.system(size: 13.zoom())).foregroundStyle(.white)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 10.zoom()).padding(.bottom, 10.zoom())
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(ChatMediaBubbleShape(own: own))
        .accessibilityLabel(message.type == 2 ? "视频，\(videoDuration)" : "图片")
    }

    private var mediaSize: CGSize {
        let width = message.mediaWidth.isFinite && message.mediaWidth > 0 ? message.mediaWidth : 1
        let height = message.mediaHeight.isFinite && message.mediaHeight > 0 ? message.mediaHeight : 1
        let side = 170.zoom()
        return width >= height
            ? CGSize(width: side, height: max(24.zoom(), side * height / width))
            : CGSize(width: max(24.zoom(), side * width / height), height: side)
    }

    private var videoDuration: String {
        let seconds = message.duration.isFinite && message.duration > 0 ? Int(min(message.duration, 86_400)) : 0
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    /// 贴纸协议可能没有GIF扩展名，普通照片只在真实URL标明GIF时启用动画。
    private var isAnimatedResource: Bool {
        guard message.status == .normal else { return false }
        if message.type == 12 { return true }
        guard message.type == 1 else { return false }
        return [message.resource, message.thumbnail].contains { URL(string: $0)?.pathExtension.lowercased() == "gif" }
    }
}

/// 旧端媒体气泡靠近头像的一侧上角较小，另一侧保持圆角。
private struct ChatMediaBubbleShape: Shape {
    let own: Bool
    var media = true
    func path(in rect: CGRect) -> Path {
        if !media { return Path(roundedRect: rect, cornerRadius: 8.zoom()) }
        let large = min(18.zoom(), rect.width / 2, rect.height / 2)
        let small = min(3.zoom(), rect.width / 2, rect.height / 2)
        let topLeft = own ? large : small
        let topRight = own ? small : large
        return Path { path in
            path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + topRight), control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - large))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - large, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + large, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - large), control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
            path.addQuadCurve(to: CGPoint(x: rect.minX + topLeft, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
            path.closeSubpath()
        }
    }
}

/// 部分已读沿用旧端圆环加扇形填充，零和全部已读使用旧端图标。
private struct ChatReadPie: Shape {
    let progress: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return Path { path in
            path.move(to: center)
            path.addArc(center: center, radius: min(rect.width, rect.height) / 2,
                        startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * Double(progress)), clockwise: false)
            path.closeSubpath()
        }
    }
}
