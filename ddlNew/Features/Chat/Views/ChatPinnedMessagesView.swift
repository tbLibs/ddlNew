//
//  ChatPinnedMessagesView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

struct ChatPinnedMessagesView: View {
    let messages: [ChatMessageRecord]
    let onLocate: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        MessagingScroll {
            LazyVStack(spacing: 0) {
                if messages.isEmpty {
                    Label("暂无置顶消息", systemImage: "pin.slash").foregroundStyle(MessagingTheme.secondaryText).padding(.vertical, 48.zoom())
                } else {
                    Text("点击消息，回到聊天中的原位置").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText).frame(maxWidth: .infinity, alignment: .leading).padding(16.zoom())
                    ForEach(messages) { item in
                        Button { onLocate(item.serverID.isEmpty ? item.localID : item.serverID); dismiss() } label: { ChatSecondaryRecordRow(message: item) }
                            .buttonStyle(MessagingRowStyle()).accessibilityHint("返回聊天并定位此消息")
                        Divider().overlay(MessagingTheme.divider).padding(.leading, 72.zoom())
                    }
                }
            }
        }
        .navigationTitle("置顶消息").modifier(MessagingPageChrome())
    }
}
