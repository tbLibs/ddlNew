//
//  ChatPinnedMessagesView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

struct ChatPinnedMessagesView: View {
    let messages: [ChatMessageRecord]
    let onLocate: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View { List(messages) { item in Button { onLocate(item.serverID); dismiss() } label: { VStack(alignment: .leading) { Text(item.text).lineLimit(3); Text(item.senderName).font(.caption).foregroundStyle(.secondary) } } }.navigationTitle("置顶消息") }
}
