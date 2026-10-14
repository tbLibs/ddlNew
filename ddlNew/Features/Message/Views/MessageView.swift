//
//  MessageView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI
import UIAdapter
import Kingfisher

/// 真实 SDK 会话列表，操作经服务端确认后回读数据库。
struct MessageView: View {
    @ObservedObject var store: ConversationsStore
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    @ObservedObject private var authentication = IMUserAuthenticationService.shared
    @ObservedObject private var permissions = UserRoleAuthorityStore.shared
    @ObservedObject private var groups = LoginSessionService.shared.groups
    @State private var query = ""
    @State private var filter: ConversationFilter = .all
    @FocusState private var searchFocused: Bool
    @State private var deletingConversation: ConversationRecord?
    @State private var selectingMembers = false
    @EnvironmentObject private var navigation: ActivityNavigation

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
        List {
            VStack(alignment: .leading, spacing: 10.zoom()) {
                MessagingSearchField(placeholder: "搜索会话或消息预览", text: $query,
                                     focus: $searchFocused, identifier: "messageSearch")
                MessagingTabs(selection: $filter)
                if authentication.state != .ready {
                    Label(authentication.state.message, systemImage: "wifi.exclamationmark")
                        .font(.callout).foregroundStyle(MessagingTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("messageConnectionState")
                }
                if store.errorMessage?.hasPrefix("会话缓存读取失败") == true { Button("重新读取") { Task { await store.reload() } }.frame(minHeight: 44) }
            }
            .listRowInsets(EdgeInsets(top: 4.zoom(), leading: 16.zoom(), bottom: 12.zoom(), trailing: 16.zoom()))
            .listRowBackground(Color.clear).listRowSeparator(.hidden)
            if visibleConversations.isEmpty {
                emptyState.listRowBackground(Color.clear).listRowSeparator(.hidden)
            } else {
                ForEach(visibleConversations) { conversation in
                    conversationLink(conversation)
                        .contextMenu { conversationActions(conversation) }
                        .accessibilityActions { conversationActions(conversation) }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            conversationActions(conversation, actions: [.togglePin, .toggleMute])
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            conversationActions(conversation, actions: [.delete, .toggleUnread])
                        }
                        .disabled(store.busyConversationIDs.contains(conversation.id))
                        .accessibilityIdentifier("conversation.\(conversation.id)")
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(MessagingTheme.surface).listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden).background(MessagingTheme.background)
        .frame(maxWidth: 720).frame(maxWidth: .infinity)
        .background(MessagingTheme.background)
        .safeAreaInset(edge: .top, spacing: 0.zoom()) { header }
        .tint(MessagingTheme.accent)
        .messagingFeedbackToast(store.operationError ?? store.errorMessage, isEnabled: !selectingMembers)
        .modifier(ClubKeyboardDismissal(isFocused: searchFocused, tint: MessagingTheme.accent, background: MessagingTheme.surface) { searchFocused = false })
        .task { await store.reload() }
        .refreshable { await store.reload() }
        .sheet(isPresented: $selectingMembers) {
            GroupMemberPickerView(contacts: LoginSessionService.shared.contacts.contacts,
                recentIDs: store.conversations.filter { $0.kind == .single }.map(\.id),
                friendGroups: LoginSessionService.shared.contactBusiness.groups,
                submissionError: groups.errorMessage, onSubmit: { members in
                    guard let group = await groups.create(members: members,
                        nickname: UserSessionStore.shared.currentUser?.nickname ?? "") else { return false }
                    navigation.open(ChatRoute(id: group.id, kind: .group, title: group.name, avatarURL: group.avatar))
                    return true
                }, onConfirm: { _ in })
        }

        .alert("删除会话？", isPresented: Binding(get: { deletingConversation != nil }, set: { if !$0 { deletingConversation = nil } })) {
            Button("取消", role: .cancel) { deletingConversation = nil }
            Button("删除", role: .destructive) {
                if let id = deletingConversation?.id { Task { await store.perform(.delete, conversationID: id) } }
                deletingConversation = nil
            }
        } message: { Text("删除后会移除会话，聊天记录仍保留。") }
    }

    /// 固定紧凑页头，保留全局搜索、建群及权限控制的添加菜单。
    private var header: some View {
        HStack(spacing: 8.zoom()) {
            Text("消息").font(.headline).foregroundStyle(MessagingTheme.text).accessibilityAddTraits(.isHeader)
            if store.isSyncing {
                ProgressView().accessibilityLabel("正在同步会话")
            } else {
                Text("\(store.conversations.count)").font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                    .accessibilityLabel("\(store.conversations.count)个会话").accessibilityIdentifier("conversationCount")
            }
            Spacer(minLength: 0)
            NavigationLink(value: ContactsPageRoute.globalSearch) {
                Image(systemName: "magnifyingglass").font(.system(size: 22.zoom())).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
            }.accessibilityLabel("搜索好友、群聊和聊天内容").accessibilityIdentifier("openGlobalSearch")
            Menu {
                if permissions.current?.allows("allowAddFriend") == true {
                    NavigationLink("添加好友", value: ContactsPageRoute.addFriend)
                }
                if permissions.current?.allows("createGroup") == true { Button("创建群聊") { selectingMembers = true } }
                NavigationLink("扫一扫", value: ContactsPageRoute.scanner)
            } label: {
                Image(systemName: "plus.circle").font(.system(size: 22.zoom())).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
            }.accessibilityLabel("消息页面更多操作")
        }
        .foregroundStyle(MessagingTheme.text).padding(.horizontal, 16.zoom()).padding(.vertical, 4.zoom())
        .frame(maxWidth: 720).frame(maxWidth: .infinity)
        .background(MessagingTheme.background)
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
        return VStack(spacing: 14.zoom()) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 30.zoom()))
                .foregroundColor(MessagingTheme.accent)
                .frame(width: 72.zoom(), height: 72.zoom())
                .background(MessagingTheme.avatarBackground, in: RoundedRectangle(cornerRadius: 23.zoom()))
                .accessibilityHidden(true)
            Text(title).font(.headline).foregroundColor(MessagingTheme.text)
            Text(detail).font(.subheadline).foregroundColor(MessagingTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24.zoom())
        .padding(.vertical, 48.zoom())
        .accessibilityIdentifier("conversationsEmptyState")
    }

    /// 单群聊打开真实聊天，特殊业务只显示已接入的明确入口。
    @ViewBuilder private func conversationLink(_ conversation: ConversationRecord) -> some View {
        switch conversation.kind {
        case .single, .group:
            Button {
                navigation.open(ChatRoute(id: conversation.id, kind: conversation.kind,
                    title: conversation.title, avatarURL: conversation.avatarURL))
            } label: { conversationRow(conversation) }
                .buttonStyle(MessagingRowStyle())
        case .systemMessage:
            NavigationLink(value: ContactsPageRoute.groupAssistant) { conversationRow(conversation) }.buttonStyle(MessagingRowStyle())
        default: conversationRow(conversation)
        }
    }

    /// 上下文菜单复用同一操作策略，助手与特殊会话不会出现无效操作。
    @ViewBuilder private func conversationActions(_ conversation: ConversationRecord, actions: [ConversationAction] = [.togglePin, .toggleMute, .toggleUnread, .delete]) -> some View {
        let allowed = ConversationActionPolicy.allowed(for: conversation).filter { actions.contains($0) }
        if allowed.contains(.togglePin) {
            Button {
                Task { await store.perform(.togglePin, conversationID: conversation.id) }
            } label: { Label(conversation.isPinned ? "取消置顶" : "置顶", systemImage: conversation.isPinned ? "pin.slash" : "pin") }
        }
        if allowed.contains(.toggleMute) {
            Button {
                Task { await store.perform(.toggleMute, conversationID: conversation.id) }
            } label: { Label(conversation.isMuted ? "取消免打扰" : "免打扰", systemImage: "bell.slash") }
        }
        if allowed.contains(.toggleUnread) {
            Button {
                Task { await store.perform(.toggleUnread, conversationID: conversation.id) }
            } label: { Label(conversation.unreadCount > 0 || conversation.isMarkedUnread ? "清除未读" : "标记未读", systemImage: "envelope.badge") }
        }
        if allowed.contains(.delete) {
            Button(role: .destructive) { deletingConversation = conversation } label: { Label("删除会话", systemImage: "trash") }
        }
    }

    /// 平铺行对齐老项目头像、摘要和右侧状态列，辅助字号允许增高。
    private func conversationRow(_ conversation: ConversationRecord) -> some View {
        HStack(spacing: 12.zoom()) {
            avatar(for: conversation)
                .overlay(alignment: .topLeading) {
                    if conversation.isPinned {
                        Image(systemName: "pin.fill").font(.caption2).foregroundStyle(MessagingTheme.accent)
                            .padding(3.zoom()).background(MessagingTheme.surface, in: Circle())
                            .offset(x: (-10).zoom(), y: (-2).zoom()).accessibilityHidden(true)
                    }
                }
            VStack(alignment: .leading, spacing: 6.zoom()) {
                Text(conversation.title.isEmpty ? "未命名会话" : conversation.title)
                    .font(.body.weight(.medium)).foregroundStyle(MessagingTheme.text).lineLimit(2)
                preview(for: conversation)
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 10.zoom()) {
                if let latestTime = conversation.latestTime {
                    Text(Self.displayTime(latestTime)).font(.caption).foregroundStyle(MessagingTheme.secondaryText).fixedSize()
                }
                HStack(spacing: 6.zoom()) {
                    if conversation.isMuted {
                        Image(systemName: "bell.slash.fill").font(.caption2).foregroundStyle(MessagingTheme.secondaryText).accessibilityHidden(true)
                    }
                    unreadIndicator(for: conversation)
                }
            }.frame(minHeight: 50.zoom(), alignment: .topTrailing)
        }
        .padding(.horizontal, 16.zoom()).padding(.vertical, 14.zoom())
        .frame(maxWidth: .infinity, minHeight: 80.zoom(), alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { MessagingTheme.divider.frame(height: 0.5).padding(.leading, 78.zoom()) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: conversation))
    }

    /// 草稿仅替代最新摘要，不修改消息历史。
    private func preview(for conversation: ConversationRecord) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4.zoom()) {
            if conversation.isDraft {
                Text("草稿").font(.subheadline.weight(.semibold)).foregroundColor(MessagingTheme.error)
            }
            Text(conversation.preview.isEmpty ? "暂无消息预览" : conversation.preview)
                .font(.subheadline)
                .foregroundColor(MessagingTheme.secondaryText)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    /// 真实未读与手动未读分别呈现，免打扰使用静音颜色。
    private func unreadIndicator(for conversation: ConversationRecord) -> some View {
        if conversation.unreadCount > 0 {
            Text(conversation.unreadCount > 99 ? "99+" : String(conversation.unreadCount))
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6.zoom())
                .frame(minWidth: 20.zoom(), minHeight: 20.zoom())
                .background(conversation.isMuted ? MessagingTheme.mutedBadge : MessagingTheme.badge, in: Capsule())
                .accessibilityHidden(true)
        } else if conversation.isMarkedUnread {
            Circle()
                .fill(conversation.isMuted ? MessagingTheme.mutedBadge : MessagingTheme.badge)
                .frame(width: 9.zoom(), height: 9.zoom())
                .padding(.top, 5.zoom())
                .accessibilityHidden(true)
        }
    }

    /// 相对头像从当前文件节点加载，失败显示对应会话占位。
    private func avatar(for conversation: ConversationRecord) -> some View {
        let fileHost = connection.current?.getFileHost
        let url = RemoteAvatarURL.resolve(conversation.avatarURL, relativeTo: fileHost)
        return KFImage(url)
            .downloader(NetworkImageDownloader.downloader(for: fileHost))
            .setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: 50.zoom(), height: 50.zoom())))
            .cacheOriginalImage()
            .cancelOnDisappear(true)
            .placeholder { avatarPlaceholder(for: conversation.kind) }
            .resizable()
            .scaledToFill()
            .frame(width: 50.zoom(), height: 50.zoom())
            .clipShape(Circle())
            .overlay(Circle().stroke(MessagingTheme.border, lineWidth: 1))
            .accessibilityHidden(true)
    }

    /// 使用可辨识的系统图标表示无头像的会话类型。
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
            .font(.system(size: 22.zoom(), weight: .medium))
            .foregroundColor(MessagingTheme.accent)
            .frame(width: 50.zoom(), height: 50.zoom())
            .background(MessagingTheme.avatarBackground)
    }

    /// 合并状态文案供 VoiceOver 读取整条会话。
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

    /// 使用本地日历区分今日、昨天与较早日期。
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
