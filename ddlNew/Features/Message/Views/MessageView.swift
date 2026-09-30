//
//  MessageView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 消息列表，保留搜索、分类、已读状态与聊天入口。
struct MessageView: View {
    @EnvironmentObject private var community: ClubCommunity
    @State private var query = ""
    @State private var filter: MessageFilter = .all
    @State private var selected: ClubMessage?
    @State private var showingChat = false
    @FocusState private var searchFocused: Bool

    private var filtered: [ClubMessage] {
        community.messages.filter {
            (query.isEmpty || ($0.title + $0.preview + $0.body).localizedCaseInsensitiveContains(query)) &&
            (filter == .all || (filter == .unread && $0.unread) || (filter == .notices && $0.isNotice))
        }
    }

    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    ScreenHeading(eyebrow: "远山户外俱乐部", title: "消息")
                    Button("全部已读") { community.markAllRead() }
                        .font(.subheadline.weight(.medium)).foregroundColor(ClubTheme.darkTeal)
                        .frame(minHeight: 44).disabled(community.unreadCount == 0)
                        .opacity(community.unreadCount == 0 ? 0.45 : 1)
                        .accessibilityIdentifier("markAllMessagesRead")
                }
                HStack(spacing: 8) {
                    ClubIcon(name: "messages", size: 16)
                    Text(community.unreadCount == 0 ? "消息都已读，期待下一次相聚" : "有 \(community.unreadCount) 条未读消息，看看伙伴们的新动态")
                        .font(.subheadline)
                }.foregroundColor(ClubTheme.secondary)
                CommunitySearchField(placeholder: "搜索消息", text: $query, focus: $searchFocused, identifier: "messageSearch")
                CommunityFilters(selection: $filter)
                if filtered.isEmpty {
                    EmptyClubState(title: filter == .unread && query.isEmpty ? "暂时没有未读消息" : "没有找到相关消息", message: "试试其他关键词，或切换消息分类。")
                } else {
                    ClubCard(padding: 0) {
                        LazyVStack(spacing: 0) {
                            ForEach(filtered) { message in
                                Button {
                                    searchFocused = false
                                    community.markRead(message.id)
                                    selected = message
                                    showingChat = true
                                } label: {
                                    messageRow(message)
                                }
                                .buttonStyle(CommunityRowStyle())
                                .accessibilityIdentifier("message.\(message.id)")
                                .accessibilityLabel("\(message.title)，\(message.unread ? "未读" : "已读")，\(message.preview)，\(message.time)")
                                if message.id != filtered.last?.id {
                                    Divider().overlay(ClubTheme.border.opacity(0.4)).padding(.leading, 82)
                                }
                            }
                        }
                    }
                }
                Text("每一次相聚，都从一条消息开始")
                    .font(.footnote).foregroundColor(ClubTheme.secondary)
                    .frame(maxWidth: .infinity).padding(.top, 8)
            }.padding(.horizontal, 20).padding(.top, 18)
        }
        .modifier(ClubKeyboardDismissal(isFocused: searchFocused) { searchFocused = false })
        .navigationDestination(isPresented: $showingChat) {
            if let selected {
                ChatScreen(conversation: selected).id(selected.id)
            }
        }
    }

    private func messageRow(_ message: ClubMessage) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ClubIcon(name: message.icon, size: 23)
                .foregroundColor(ClubTheme.darkTeal)
                .frame(width: 48, height: 48)
                .background(message.isNotice ? ClubTheme.pale.opacity(0.55) : ClubTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 17))
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(message.title).font(.body.weight(message.unread ? .semibold : .medium))
                        .foregroundColor(ClubTheme.ink).lineLimit(1)
                    Spacer(minLength: 0)
                    Text(message.time).font(.caption).foregroundColor(ClubTheme.secondary).fixedSize()
                }
                HStack(alignment: .top, spacing: 8) {
                    Text(message.preview).font(.subheadline).foregroundColor(ClubTheme.secondary)
                        .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    if message.unread {
                        Circle().fill(ClubTheme.darkTeal).frame(width: 8, height: 8).padding(.top, 5)
                    }
                }
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }
}
