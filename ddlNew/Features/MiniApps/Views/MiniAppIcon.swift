//
//  MiniAppIcon.swift
//  ddlNew
//
//  Created by taobo on 2026/11/9.
//
import SwiftUI
import Kingfisher

/// 图标沿用文件节点与旧图片解包器，不引入第二套下载或证书策略。
struct MiniAppIcon: View {
    let resource: String
    var size: CGFloat = 48
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    var body: some View {
        let host = connection.current?.getFileHost
        KFImage(RemoteAvatarURL.resolve(resource, relativeTo: host))
            .downloader(NetworkImageDownloader.downloader(for: host))
            .setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: size, height: size)))
            .cancelOnDisappear(true)
            .placeholder {
                Image(systemName: "app.dashed").font(.title2).foregroundStyle(MessagingTheme.accent)
                    .frame(width: size, height: size).background(MessagingTheme.avatarBackground)
            }
            .resizable().scaledToFill().frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
    }
}
