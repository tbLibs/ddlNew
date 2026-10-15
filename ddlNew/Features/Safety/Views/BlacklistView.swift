//
//  BlacklistView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/15.
//
import SwiftUI
import UIAdapter

/// 真实名单按首字母分组，移出提供可见按钮，不依赖滑动手势。
struct BlacklistView: View {
    @ObservedObject var businessStore: ContactsBusinessStore
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    private var initials: [String] { businessStore.blacklist.reduce(into: []) { if !$0.contains($1.initial) { $0.append($1.initial) } } }

    var body: some View {
        List {
            if businessStore.blacklist.isEmpty && !businessStore.isLoadingBlacklist {
                if businessStore.errorMessage != nil { Button("重新加载") { Task { await businessStore.loadBlacklist() } }.frame(minHeight: 44) }
                else { EmptyClubState(title: "暂无黑名单用户", message: "加入黑名单的用户会显示在这里，可以随时移出。") }
            }
            ForEach(initials, id: \.self) { initial in
                Section(initial) {
                    ForEach(businessStore.blacklist.filter { $0.initial == initial }) { contact in
                        HStack(spacing: 12.zoom()) {
                            NavigationLink(value: ContactsRoute(contactID: contact.id)) {
                                HStack(spacing: 12.zoom()) {
                                    ContactRecordAvatar(contact: contact, fileHost: connection.current?.getFileHost, size: 44.zoom())
                                    VStack(alignment: .leading, spacing: 4.zoom()) {
                                        Text(contact.displayName).foregroundStyle(MessagingTheme.text)
                                        if !contact.account.isEmpty { Text(contact.account).font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
                                    }
                                }
                            }
                            Button("移出") { Task { await businessStore.perform(.setBlack(friendID: contact.id, blocked: false)) } }
                                .buttonStyle(.borderless).foregroundStyle(MessagingTheme.accent)
                                .frame(minWidth: 52, minHeight: 44).accessibilityLabel("将\(contact.displayName)移出黑名单")
                                .disabled(businessStore.isSubmitting)
                        }.frame(minHeight: max(52, 64.zoom())).listRowBackground(MessagingTheme.surface)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("黑名单").modifier(MessagingPageChrome())
        .messagingLoadingToast(businessStore.isLoadingBlacklist || businessStore.isSubmitting)
        .messagingFeedbackToast(businessStore.errorMessage ?? businessStore.notice)
        .task { await businessStore.loadBlacklist() }
        .refreshable { await businessStore.loadBlacklist() }
    }
}
