//
//  ContactShortcut.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI
import UIAdapter

/// 对齐旧通讯录顶部入口，文字可随辅助字号增高，未读不只依赖颜色。
struct ContactShortcut: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let symbol: String
    var unreadCount = 0

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: 16.zoom()) { icon; titleLabel }
            } else {
                VStack(alignment: .leading, spacing: 12.zoom()) { icon; titleLabel }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64.zoom(), alignment: .leading).padding(12.zoom())
        .background(MessagingTheme.surface)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title + (unreadCount > 0 ? "，\(unreadCount)条未读申请" : ""))
    }
    /// 图标大小不跟随正文无限放大，完整标题负责可访问语义。
    private var icon: some View {
        Image(systemName: symbol).font(.system(size: 24.zoom())).foregroundStyle(MessagingTheme.accent)
            .accessibilityHidden(true)
            .overlay(alignment: .topTrailing) {
                if unreadCount > 0 {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)").font(.system(size: 11.zoom(), weight: .bold))
                        .foregroundStyle(.white).padding(.horizontal, 5.zoom()).frame(minHeight: 18.zoom())
                        .background(MessagingTheme.badge, in: Capsule()).offset(x: (12).zoom(), y: (-8).zoom())
                }
            }
    }

    private var titleLabel: some View {
        Text(title).font(.subheadline).foregroundStyle(MessagingTheme.text).fixedSize(horizontal: false, vertical: true)
    }

}
