//
//  ChatGroupMemberPreview.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import SwiftUI
import Kingfisher

struct ChatGroupMemberPreview: View {
    let group: ChatGroupDetail
    let onInvite: () -> Void
    let onRemove: () -> Void
    private var canOpen: Bool { [1, 2].contains(group.role) || !group.isPrivateChat || UserRoleAuthorityStore.shared.current?.allows("groupSecurity") == true }
    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(ChatGroupPreviewPolicy.members(group)) { member in
                    if canOpen && member.id != UserSessionStore.shared.currentUser?.userUID { NavigationLink(value: ContactsRoute(contactID: member.id, sourceGroupID: group.id)) { avatar(member) } }
                    else { avatar(member) }
                }
                Button(action: onInvite) { Label("邀请", systemImage: "person.badge.plus").labelStyle(.iconOnly).frame(width: 48, height: 48) }.accessibilityLabel("邀请好友进群")
                if [1, 2].contains(group.role) { Button(action: onRemove) { Label("移除", systemImage: "person.badge.minus").labelStyle(.iconOnly).frame(width: 48, height: 48) }.accessibilityLabel("选择移除群成员") }
            }
        }
    }
    /// 每名真实成员显示头像、当前群角色和名称，资料路由保留来源群守卫。
    private func avatar(_ member: ChatGroupMember) -> some View {
        VStack(spacing: 4) {
            KFImage(RemoteAvatarURL.resolve(member.avatar, relativeTo: OSSConnectionBootstrap.shared.current?.getFileHost)).setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: 96, height: 96))).resizable().scaledToFill().frame(width: 48, height: 48).clipShape(Circle()).accessibilityHidden(true)
            Text(member.name).font(.caption).lineLimit(2).frame(width: 64)
            if [1, 2].contains(member.role) { Text(member.role == 2 ? "群主" : "管理员").font(.caption2).foregroundStyle(.secondary) }
        }
    }
}
