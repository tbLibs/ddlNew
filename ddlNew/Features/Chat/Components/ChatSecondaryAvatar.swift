//
//  ChatSecondaryAvatar.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI
import UIAdapter
import Kingfisher

/// 关联选人和搜索共用头像，缩放仅应用一次；节点变化重新解析资源。
struct ChatSecondaryAvatar: View {
    let name: String
    let resource: String
    let isGroup: Bool
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    var body: some View {
        let host = connection.current?.getFileHost
        KFImage(RemoteAvatarURL.resolve(resource, relativeTo: host))
            .downloader(NetworkImageDownloader.downloader(for: host))
            .setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: 44.zoom(), height: 44.zoom())))
            .cancelOnDisappear(true)
            .placeholder {
                ZStack {
                    MessagingTheme.avatarBackground
                    if isGroup { Image(systemName: "person.2.fill").foregroundStyle(MessagingTheme.accent) }
                    else { Text(String(name.prefix(1))).font(.body.weight(.medium)).foregroundStyle(MessagingTheme.text) }
                }
            }
            .resizable().scaledToFill().frame(width: 44.zoom(), height: 44.zoom())
            .clipShape(RoundedRectangle(cornerRadius: 8.zoom())).accessibilityHidden(true)
    }
}
