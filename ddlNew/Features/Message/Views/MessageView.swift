//
//  MessageView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI
import Kingfisher

/// SDK 会话列表。聊天页接入真实消息前，列表只展示数据库状态。
struct MessageView: View {
    @ObservedObject var store: ConversationsStore
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    @State private var query = ""
    @State private var filter: ConversationFilter = .all
    @FocusState private var searchFocused: Bool

    private enum ConversationFilter: String, CaseIterable, Identifiable {
        case all = "全部"
        case unread = "未读"
        var id: Self { self }
    }

    private var visibleConversations: [ConversationRecord] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.conversations.filter { conversation in
            let matchesQuery = keyword.isEmpty || conversation.title.localizedCaseInsensitiveContains(keyword)
                || conversation.preview.localizedCaseInsensitiveContains(keyword)
            let matchesFilter = filter == .all || conversation.unreadCount > 0 || conversation.isMarkedUnread
            return matchesQuery && matchesFilter
        }
    }

    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 18) {
                header
                CommunitySearchField(placeholder: "搜索会话或消息预览", text: $query,
                                     focus: $searchFocused, identifier: "messageSearch")
                CommunityFilters(selection: $filter)
                if let error = store.errorMessage { errorNotice(error) }
                if visibleConversations.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(visibleConversations) { conversation in
                            conversationRow(conversation)
                                .accessibilityIdentifier("conversation.\(conversation.id)")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
        }
        .modifier(ClubKeyboardDismissal(isFocused: searchFocused) { searchFocused = false })
        .task { await store.reload() }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ScreenHeading(eyebrow: "与伙伴保持联系", title: "消息")
                .accessibilityAddTraits(.isHeader)
            if store.isSyncing {
                ProgressView()
                    .tint(ClubTheme.darkTeal)
                    .padding(.bottom, 5)
                    .accessibilityLabel("正在同步会话")
            } else {
                Text("\(store.conversations.count) 个会话")
                    .font(.subheadline)
                    .foregroundColor(ClubTheme.secondary)
                    .padding(.bottom, 4)
                    .accessibilityIdentifier("conversationCount")
            }
        }
    }

    private func errorNotice(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle")
                    .font(.subheadline)
                    .accessibilityHidden(true)
                Text(message).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            // SDK 同步由 SDK 自行恢复；这里仅重试本地缓存读取失败。
            if message.hasPrefix("会话缓存读取失败") {
                Button("重新读取") { Task { await store.reload() } }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("retryConversationsCache")
            }
        }
        .foregroundColor(ClubTheme.error)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ClubTheme.error.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("conversationsSyncError")
    }

    private var emptyState: some View {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let title: String
        let detail: String
        if !keyword.isEmpty {
            title = "没有找到相关会话"
            detail = "试试搜索联系人名称或消息内容。"
        } else if store.isSyncing && store.conversations.isEmpty {
            title = "正在同步会话…"
            detail = "同步完成后，消息会显示在这里。"
        } else if let error = store.errorMessage, store.conversations.isEmpty {
            title = "会话列表暂时不可用"
            detail = error.hasPrefix("会话缓存读取失败")
                ? "请重新读取会话缓存，或稍后再查看。"
                : "网络恢复后会自动同步，你也可以稍后再查看。"
        } else if filter == .unread {
            title = "暂无未读会话"
            detail = "有新消息时，会显示在这里。"
        } else {
            title = "暂无会话"
            detail = "收到新消息后，会话会显示在这里。"
        }
        return VStack(spacing: 14) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 30))
                .foregroundColor(ClubTheme.darkTeal)
                .frame(width: 72, height: 72)
                .background(ClubTheme.wash, in: RoundedRectangle(cornerRadius: 23))
                .accessibilityHidden(true)
            Text(title).font(.headline).foregroundColor(ClubTheme.ink)
            Text(detail).font(.subheadline).foregroundColor(ClubTheme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
        .accessibilityIdentifier("conversationsEmptyState")
    }

    private func conversationRow(_ conversation: ConversationRecord) -> some View {
        HStack(alignment: .top, spacing: 13) {
            avatar(for: conversation)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(conversation.title.isEmpty ? "未命名会话" : conversation.title)
                        .font(.body.weight(conversation.unreadCount > 0 || conversation.isMarkedUnread ? .semibold : .medium))
                        .foregroundColor(ClubTheme.ink)
                        .lineLimit(1)
                    if conversation.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption2)
                            .foregroundColor(ClubTheme.secondary)
                            .accessibilityHidden(true)
                    }
                    Spacer(minLength: 0)
                    if let latestTime = conversation.latestTime {
                        Text(Self.displayTime(latestTime))
                            .font(.caption)
                            .foregroundColor(ClubTheme.secondary)
                            .fixedSize()
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    preview(for: conversation)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    unreadIndicator(for: conversation)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ClubTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ClubTheme.border, lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            if conversation.isPinned {
                RoundedRectangle(cornerRadius: 2)
                    .fill(ClubTheme.darkTeal)
                    .frame(width: 4)
                    .padding(.vertical, 12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: conversation))
    }

    private func preview(for conversation: ConversationRecord) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if conversation.isDraft {
                Text("草稿").font(.subheadline.weight(.semibold)).foregroundColor(ClubTheme.error)
            }
            Text(conversation.preview.isEmpty ? "暂无消息预览" : conversation.preview)
                .font(.subheadline)
                .foregroundColor(ClubTheme.secondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private func unreadIndicator(for conversation: ConversationRecord) -> some View {
        if conversation.unreadCount > 0 {
            Text(conversation.unreadCount > 99 ? "99+" : String(conversation.unreadCount))
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .frame(minWidth: 20, minHeight: 20)
                .background(conversation.isMuted ? ClubTheme.secondary : ClubTheme.error, in: Capsule())
                .accessibilityHidden(true)
        } else if conversation.isMarkedUnread {
            Circle()
                .fill(conversation.isMuted ? ClubTheme.secondary : ClubTheme.error)
                .frame(width: 9, height: 9)
                .padding(.top, 5)
                .accessibilityHidden(true)
        }
    }

    private func avatar(for conversation: ConversationRecord) -> some View {
        let fileHost = connection.current?.getFileHost
        let url = RemoteAvatarURL.resolve(conversation.avatarURL, relativeTo: fileHost)
        return KFImage(url)
            .downloader(NetworkImageDownloader.downloader(for: fileHost))
            .downsampling(size: CGSize(width: 50, height: 50))
            .cacheOriginalImage()
            .cancelOnDisappear(true)
            .placeholder { avatarPlaceholder(for: conversation.kind) }
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .accessibilityHidden(true)
    }

    private func avatarPlaceholder(for kind: ConversationKind) -> some View {
        let symbol: String
        switch kind {
        case .single: symbol = "person.fill"
        case .group: symbol = "person.2.fill"
        case .massMessage: symbol = "paperplane.fill"
        case .systemMessage: symbol = "bell.fill"
        case .signInReminder: symbol = "checkmark.circle.fill"
        case .paymentAssistant: symbol = "creditcard.fill"
        }
        return Image(systemName: symbol)
            .font(.system(size: 22, weight: .medium))
            .foregroundColor(ClubTheme.darkTeal)
            .frame(width: 50, height: 50)
            .background(ClubTheme.pale)
    }

    private func accessibilityLabel(for conversation: ConversationRecord) -> String {
        var parts = [conversation.title.isEmpty ? "未命名会话" : conversation.title]
        if conversation.isPinned { parts.append("已置顶") }
        if conversation.isMuted { parts.append("免打扰") }
        if conversation.unreadCount > 0 { parts.append("\(conversation.unreadCount) 条未读") }
        else if conversation.isMarkedUnread { parts.append("标记未读") }
        if conversation.isDraft { parts.append("草稿") }
        if !conversation.preview.isEmpty { parts.append(conversation.preview) }
        if let date = conversation.latestTime { parts.append(Self.displayTime(date)) }
        return parts.joined(separator: "，")
    }

    private static func displayTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: .now) {
            formatter.dateFormat = "M月d日"
        } else {
            formatter.dateFormat = "yyyy/M/d"
        }
        return formatter.string(from: date)
    }
}
