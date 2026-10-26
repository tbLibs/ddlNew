//
//  MassMessageRecipientsView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/23.
//

import SwiftUI
import UIAdapter

struct MassMessageRecipientsView: View {
    let failures: Bool
    @StateObject private var store: MassMessageRecipientsStore
    init(context: ChatContext, record: MassMessageRecord, failures: Bool) {
        self.failures = failures
        _store = StateObject(wrappedValue: MassMessageRecipientsStore(context: context, record: record, failures: failures))
    }
    var body: some View {
        List {
            ForEach(store.recipients) { recipient in
                HStack(alignment: .top, spacing: 12.zoom()) {
                    ChatSecondaryAvatar(name: recipient.name, resource: recipient.avatar, isGroup: recipient.isGroup)
                    VStack(alignment: .leading, spacing: 6.zoom()) {
                        Text(recipient.name).font(.body)
                        Text(recipient.isGroup ? "群聊" : "好友").font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                        if failures { Text(recipient.error.isEmpty ? "发送失败" : recipient.error).font(.subheadline).foregroundStyle(MessagingTheme.error) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.vertical, 8.zoom()).listRowBackground(MessagingTheme.surface)
            }
            if !store.loading && store.recipients.isEmpty {
                Text(store.errorMessage == nil ? (failures ? "暂无失败记录" : "暂无接收对象") : "加载失败，请下拉重试")
                    .foregroundStyle(MessagingTheme.secondaryText).frame(maxWidth: .infinity).padding(.vertical, 24.zoom())
            }
            if store.hasMore && !store.recipients.isEmpty {
                Button("加载更多") { Task { await store.loadMore() } }.frame(maxWidth: .infinity, minHeight: 44).disabled(store.loading)
            }
        }.listStyle(.plain).navigationTitle(failures ? "发送失败" : "全部接收对象").modifier(MessagingPageChrome())
            .task { await store.reload() }.refreshable { await store.reload() }
            .messagingLoadingToast(store.loading && store.recipients.isEmpty)
            .messagingFeedbackToast(store.errorMessage)
            .onDisappear { store.close() }
    }
}
