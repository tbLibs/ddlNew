//
//  ChatSecondaryRecordRow.swift
//  ddlNew
//
//  Created by taobo on 2026/10/14.
//

import SwiftUI
import UIAdapter

/// 搜索和置顶沿用旧版作者、摘要、时间排列，附件保留实际类型和文件名。
struct ChatSecondaryRecordRow: View {
    let message: ChatMessageRecord
    var body: some View {
        HStack(alignment: .top, spacing: 12.zoom()) {
            ChatSecondaryAvatar(name: message.senderName, resource: message.avatarURL, isGroup: false)
            VStack(alignment: .leading, spacing: 6.zoom()) {
                ViewThatFits(in: .horizontal) {
                    HStack { Text(message.senderName.isEmpty ? "未知发送者" : message.senderName).font(.subheadline.weight(.semibold)); Spacer(); date }
                    VStack(alignment: .leading, spacing: 4.zoom()) { Text(message.senderName.isEmpty ? "未知发送者" : message.senderName).font(.subheadline.weight(.semibold)); date }
                }
                Text(message.displayText).font(.body).foregroundStyle(MessagingTheme.text).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                if message.type == 5 && message.size > 0 { Text(ByteCountFormatter.string(fromByteCount: message.size, countStyle: .file)).font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(MessagingTheme.secondaryText).accessibilityHidden(true)
        }
        .foregroundStyle(MessagingTheme.text)
        .padding(16.zoom()).frame(maxWidth: .infinity, minHeight: max(44, 44.zoom()), alignment: .leading).contentShape(Rectangle())
    }
    private var date: some View { Text(Date(timeIntervalSince1970: Double(message.timestamp) / 1000), format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
}

