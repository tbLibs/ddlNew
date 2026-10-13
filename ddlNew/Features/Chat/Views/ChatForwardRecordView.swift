//
//  ChatForwardRecordView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

struct ChatForwardRecordView: View {
    let message: ChatMessageRecord
    let context: ChatContext
    @State private var media: ChatMessageRecord?
    @State private var location: ChatMessageRecord?
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if message.nestedMessages.isEmpty { Text("聊天记录资源暂不可用，请稍后重试").foregroundStyle(.secondary) }
                ForEach(message.nestedMessages) { item in
                    if item.type == 6 && !item.cardUID.isEmpty { NavigationLink("查看名片：" + item.text, value: ContactsRoute(contactID: item.cardUID, sourceGroupID: context.route.kind == .group ? context.route.id : context.route.sourceGroupID)) }
                    ChatMessageBubble(message: item, own: false, isSelected: false, isHighlighted: false, onRetry: {})
                        .onTapGesture { open(item) }
                        .accessibilityAction(named: "查看记录内附件") { open(item) }
                }
            }.padding()
        }
        .navigationTitle(message.text.isEmpty ? "聊天记录" : message.text)
        .sheet(item: $location) { item in NavigationStack { ChatLocationDetailView(message: item) } }
        .sheet(item: $media) { item in NavigationStack { ChatMediaDetailView(message: item, context: context, allowSharing: false, onVoicePlayed: {}) } }
    }
    /// 合并记录内仅可打开媒体，不开放转发、收藏和系统分享。
    private func open(_ item: ChatMessageRecord) { if [1, 2, 4, 5, 12].contains(item.type) { media = item }; if [3, 7].contains(item.type) { location = item } }
}
