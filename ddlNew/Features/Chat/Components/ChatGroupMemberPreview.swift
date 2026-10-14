//
//  ChatGroupMemberPreview.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import SwiftUI
import Kingfisher
import UIAdapter

struct ChatGroupMemberPreview: View {
    let group: ChatGroupDetail
    let onOpenMembers: () -> Void
    let onInvite: () -> Void
    let onRemove: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize
    private var canOpen: Bool { [1, 2].contains(group.role) || !group.isPrivateChat || UserRoleAuthorityStore.shared.current?.allows("groupSecurity") == true }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: textSize.isAccessibilitySize ? 100.zoom() : 60.zoom()), alignment: .top)], alignment: .leading, spacing: 16.zoom()) {
            ForEach(ChatGroupPreviewPolicy.members(group)) { member in
                if canOpen && group.membersSyncReady {
                    Button(action: onOpenMembers) { avatar(member) }
                        .buttonStyle(MessagingRowStyle())
                } else { avatar(member) }
            }
            action("邀请", icon: "plus", perform: onInvite)
            if [1, 2].contains(group.role) { action("移除", icon: "minus", perform: onRemove) }
        }
    }

    /// 成员预览与列表复用真实头像，角色与资料路由仍按服务端权限展示。
    private func avatar(_ member: ChatGroupMember) -> some View {
        VStack(spacing: 6.zoom()) {
            ChatGroupMemberAvatar(member: member, size: 48.zoom())
            Text(member.name).font(.caption).foregroundStyle(MessagingTheme.text).lineLimit(textSize.isAccessibilitySize ? nil : 2)
            if [1, 2].contains(member.role) { Text(member.role == 2 ? "群主" : "管理员").font(.caption2).foregroundStyle(MessagingTheme.accent) }
        }.frame(maxWidth: .infinity, alignment: .top).accessibilityElement(children: .combine)
    }

    /// 加减入口与成员网格同尺寸，文字说明不依赖图标颜色。
    private func action(_ title: String, icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 6.zoom()) {
                Image(systemName: icon).font(.title2).frame(width: max(44, 48.zoom()), height: max(44, 48.zoom()))
                    .foregroundStyle(MessagingTheme.secondaryText).background(MessagingTheme.pressed, in: RoundedRectangle(cornerRadius: 8.zoom())).accessibilityHidden(true)
                Text(title).font(.caption).foregroundStyle(MessagingTheme.text)
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .top)
        }.buttonStyle(MessagingRowStyle()).accessibilityLabel(title == "邀请" ? "邀请好友进群" : "选择移除群成员")
    }
}

/// 群成员尚无独立头像组件，下载策略和文件 Host 与好友头像保持一致。
struct ChatGroupMemberAvatar: View {
    let member: ChatGroupMember
    let size: CGFloat
    @ObservedObject private var connection = OSSConnectionBootstrap.shared

    var body: some View {
        let host = connection.current?.getFileHost
        KFImage(member.isDeleted ? nil : RemoteAvatarURL.resolve(member.avatar, relativeTo: host))
            .downloader(NetworkImageDownloader.downloader(for: host))
            .setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: size * 2, height: size * 2)))
            .cancelOnDisappear(true)
            .placeholder { ZStack { MessagingTheme.avatarBackground; Text(String(member.name.prefix(1))).font(.headline).foregroundStyle(MessagingTheme.text) } }
            .resizable().scaledToFill().frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8.zoom())).accessibilityHidden(true)
    }
}
