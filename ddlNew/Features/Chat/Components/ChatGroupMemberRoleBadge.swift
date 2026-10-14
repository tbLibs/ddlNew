//
//  ChatGroupMemberRoleBadge.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI
import UIAdapter

/// 预览、成员名单和移除页共用群角色标识，沿用首页森林绿主题。
struct ChatGroupMemberRoleBadge: View {
    let member: ChatGroupMember

    var body: some View {
        if let title = member.groupRoleTitle {
            Text(title).font(.caption2.weight(.semibold))
                .foregroundStyle(MessagingTheme.accent)
                .padding(.horizontal, 7.zoom()).padding(.vertical, 3.zoom())
                .background(MessagingTheme.avatarBackground, in: RoundedRectangle(cornerRadius: 4.zoom()))
                .overlay { RoundedRectangle(cornerRadius: 4.zoom()).stroke(MessagingTheme.accent.opacity(0.35), lineWidth: 0.5) }
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
