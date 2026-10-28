//
//  ChatContactCardContent.swift
//  ddlNew
//
//  Created by taobo on 2026/10/27.
//

import SwiftUI
import UIAdapter
import Kingfisher

/// 名片正文读取被推荐用户的快照，不能复用消息发送者的头像和昵称。
struct ChatContactCardContent: View {
    let name: String
    let avatar: String
    let fileHost: URL?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var displayName: String { name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "用户" : name }

    var body: some View {
        VStack(alignment: .leading, spacing: 4.zoom()) {
            HStack(spacing: 10.zoom()) {
                KFImage(RemoteAvatarURL.resolve(avatar, relativeTo: fileHost))
                    .setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: 80.zoom(), height: 80.zoom())))
                    .downloader(NetworkImageDownloader.downloader(for: fileHost))
                    .cancelOnDisappear(true)
                    .placeholder {
                        Image(systemName: "person.fill")
                            .font(.system(size: 18.zoom(), weight: .medium))
                            .foregroundStyle(MessagingTheme.accent)
                            .frame(width: 40.zoom(), height: 40.zoom())
                            .background(MessagingTheme.avatarBackground)
                    }
                    .resizable().scaledToFill()
                    .frame(width: 40.zoom(), height: 40.zoom()).clipShape(Circle())
                    .accessibilityHidden(true)
                Text(displayName)
                    .font(.body).foregroundStyle(MessagingTheme.text)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Rectangle().fill(MessagingTheme.accent.opacity(0.3)).frame(height: 1)
            Text("个人名片").font(.caption)
                .foregroundStyle(MessagingTheme.secondaryText)
        }
        // 旧端正文230点，外加气泡左右各10点留白；窄窗按父容器收缩，大字号允许增高。
        .frame(maxWidth: 230.zoom(), minHeight: 65.zoom(), alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("个人名片，" + displayName)
    }
}
