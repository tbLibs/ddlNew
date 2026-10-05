//
//  ContactRecordAvatar.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import SwiftUI
import Kingfisher

/// 真实好友头像；下载失败或账号已注销时显示本地占位图。
struct ContactRecordAvatar: View {
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    let contact: ContactRecord
    let fileHost: URL?
    let size: CGFloat

    var body: some View {
        let currentHost = connection.current?.getFileHost ?? fileHost
        KFImage(contact.avatarURL(relativeTo: currentHost))
            .downloader(NetworkImageDownloader.downloader(for: currentHost))
            .downsampling(size: CGSize(width: size, height: size))
            .cacheOriginalImage()
            .cancelOnDisappear(true)
            .placeholder {
                ZStack {
                    ClubTheme.pale
                    if contact.isDeleted {
                        Image(systemName: "person.crop.circle.badge.minus")
                            .font(.system(size: size * 0.4)).foregroundColor(ClubTheme.secondary)
                    } else {
                        Text(String(contact.displayName.prefix(1)))
                            .font(.system(size: size * 0.36, weight: .medium, design: .rounded))
                            .foregroundColor(ClubTheme.ink)
                    }
                }
            }
        .resizable().scaledToFill()
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.35))
        .accessibilityHidden(true)
    }
}
