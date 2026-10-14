//
//  ChatForwardRecordView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

struct ChatForwardRecordView: View {
    let message: ChatMessageRecord
    let context: ChatContext
    @State private var media: ChatMessageRecord?
    @State private var location: ChatMessageRecord?
    var body: some View {
        MessagingScroll {
            LazyVStack(alignment: .leading, spacing: 0) {
                if message.nestedMessages.isEmpty { Label("聊天记录资源暂不可用，请稍后重试", systemImage: "doc.text.magnifyingglass").foregroundStyle(MessagingTheme.secondaryText).padding(24.zoom()) }
                ForEach(message.nestedMessages) { item in
                    if item.type == 6 && !item.cardUID.isEmpty {
                        NavigationLink(value: ContactsRoute(contactID: item.cardUID, sourceGroupID: context.route.kind == .group ? context.route.id : context.route.sourceGroupID)) { ChatSecondaryRecordRow(message: item) }.buttonStyle(MessagingRowStyle())
                    } else if [1, 2, 3, 4, 5, 7, 12].contains(item.type) {
                        Button { open(item) } label: { ChatSecondaryRecordRow(message: item) }.buttonStyle(MessagingRowStyle()).accessibilityHint("打开记录内附件")
                    } else {
                        VStack(alignment: .leading, spacing: 8.zoom()) {
                            HStack(spacing: 12.zoom()) {
                                ChatSecondaryAvatar(name: item.senderName, resource: item.avatarURL, isGroup: false)
                                VStack(alignment: .leading, spacing: 4.zoom()) { Text(item.senderName).font(.subheadline.weight(.semibold)); Text(Date(timeIntervalSince1970: Double(item.timestamp) / 1000), format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
                            }
                            Text(item.displayText).font(.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }.padding(16.zoom()).frame(maxWidth: .infinity).background(MessagingTheme.surface)
                    }
                    Divider().overlay(MessagingTheme.divider).padding(.horizontal, 16.zoom())
                }
            }
        }
        .navigationTitle(message.text.isEmpty ? "聊天记录" : message.text).modifier(MessagingPageChrome())
        .sheet(item: $location) { item in NavigationStack { ChatLocationDetailView(message: item).toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { location = nil }.frame(minHeight: 44) } } } }
        .sheet(item: $media) { item in NavigationStack { ChatMediaDetailView(message: item, context: context, allowSharing: false, onVoicePlayed: {}).toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { media = nil }.frame(minHeight: 44) } } } }
    }
    /// 合并记录内仅可打开媒体，不开放转发、收藏和系统分享。
    private func open(_ item: ChatMessageRecord) { if [1, 2, 4, 5, 12].contains(item.type) { media = item }; if [3, 7].contains(item.type) { location = item } }
}
