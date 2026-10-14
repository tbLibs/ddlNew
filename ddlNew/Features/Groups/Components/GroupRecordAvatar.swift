//
//  GroupRecordAvatar.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter
import Kingfisher

/// 群头像每次使用当前文件Host，节点变化不固化旧OSS地址。
struct GroupRecordAvatar: View {
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    let group: GroupRecord
    let fileHost: URL?
    var body: some View {
        let host = connection.current?.getFileHost ?? fileHost
        KFImage(RemoteAvatarURL.resolve(group.avatar, relativeTo: host))
            .downloader(NetworkImageDownloader.downloader(for: host))
            .setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: 48.zoom(), height: 48.zoom()))).cancelOnDisappear(true)
            .placeholder { Image(systemName: "person.2.fill").foregroundStyle(MessagingTheme.accent).frame(width: 48.zoom(), height: 48.zoom()).background(MessagingTheme.avatarBackground) }
            .resizable().scaledToFill().frame(width: 48.zoom(), height: 48.zoom())
            .clipShape(Circle()).overlay(Circle().stroke(MessagingTheme.border, lineWidth: 1)).accessibilityHidden(true)
    }
}
