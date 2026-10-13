//
//  MessageView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI
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
    @State private var createdRoute: ChatRoute?

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
            VStack(alignment: .leading, spacing: 18) {
                header
                CommunitySearchField(placeholder: "搜索会话或消息预览", text: $query,
                                     focus: $searchFocused, identifier: "messageSearch")
                CommunityFilters(selection: $filter)
                if authentication.state != .ready {
                    Label(authentication.state.message, systemImage: "wifi.exclamationmark")
                        .font(.callout).foregroundStyle(ClubTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("messageConnectionState")
                }
                if let error = store.errorMessage { errorNotice(error) }
            }
            .listRowInsets(EdgeInsets(top: 18, leading: 20, bottom: 8, trailing: 20))
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
                        .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden).background(ClubTheme.background)
        .modifier(ClubKeyboardDismissal(isFocused: searchFocused) { searchFocused = false })
        .task { await store.reload() }
        .refreshable { await store.reload() }
        .sheet(isPresented: $selectingMembers) {
            GroupMemberPickerView(contacts: LoginSessionService.shared.contacts.contacts,
                recentIDs: store.conversations.filter { $0.kind == .single }.map(\.id),
                friendGroups: LoginSessionService.shared.contactBusiness.groups,
                submissionError: groups.errorMessage, onSubmit: { members in
                    guard let group = await groups.create(members: members,
                        nickname: UserSessionStore.shared.currentUser?.nickname ?? "") else { return false }
                    createdRoute = ChatRoute(id: group.id, kind: .group, title: group.name, avatarURL: group.avatar)
                    return true
                }, onConfirm: { _ in })
        }
        .navigationDestination(isPresented: Binding(get: { createdRoute != nil }, set: { if !$0 { createdRoute = nil } })) {
            if let createdRoute { ChatRoomView(route: createdRoute) }
        }
        .alert("删除会话？", isPresented: Binding(get: { deletingConversation != nil }, set: { if !$0 { deletingConversation = nil } })) {
            Button("取消", role: .cancel) { deletingConversation = nil }
            Button("删除", role: .destructive) {
                if let id = deletingConversation?.id { Task { await store.perform(.delete, conversationID: id) } }
                deletingConversation = nil
            }
        } message: { Text("删除后会移除会话，聊天记录仍保留。") }
        .alert("会话操作失败", isPresented: Binding(get: { store.operationError != nil }, set: { if !$0 { store.clearOperationError() } })) {
            Button("好") { store.clearOperationError() }
        } message: { Text(store.operationError ?? "请稍后重试") }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ScreenHeading(eyebrow: "与伙伴保持联系", title: "消息")
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            NavigationLink(value: ContactsPageRoute.globalSearch) {
                Image(systemName: "magnifyingglass").frame(width: 44, height: 44)
            }.accessibilityLabel("搜索好友、群聊和聊天内容")
                .accessibilityIdentifier("openGlobalSearch")
            Menu {
                if permissions.current?.allows("allowAddFriend") == true {
                    NavigationLink("添加好友", value: ContactsPageRoute.addFriend)
                }
                if permissions.current?.allows("createGroup") == true { Button("创建群聊") { selectingMembers = true } }
                NavigationLink("扫一扫", value: ContactsPageRoute.scanner)
            } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                .accessibilityLabel("消息页面更多操作")
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

    /// 同步与本地读取失败保持现有列表，提供明确的重试入口。
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

    /// 单群聊打开真实聊天，特殊业务只显示已接入的明确入口。
    @ViewBuilder private func conversationLink(_ conversation: ConversationRecord) -> some View {
        switch conversation.kind {
        case .single, .group:
            NavigationLink(value: ChatRoute(id: conversation.id, kind: conversation.kind,
                title: conversation.title, avatarURL: conversation.avatarURL)) { conversationRow(conversation) }
                .buttonStyle(.plain)
        case .systemMessage:
            NavigationLink(value: ContactsPageRoute.groupAssistant) { conversationRow(conversation) }.buttonStyle(.plain)
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

    /// 卡片承载列表摘要与状态，操作入口由父级导航和菜单提供。
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

    /// 草稿仅替代最新摘要，不修改消息历史。
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
    /// 真实未读与手动未读分别呈现，免打扰使用静音颜色。
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

    /// 相对头像从当前文件节点加载，失败显示对应会话占位。
    private func avatar(for conversation: ConversationRecord) -> some View {
        let fileHost = connection.current?.getFileHost
        let url = RemoteAvatarURL.resolve(conversation.avatarURL, relativeTo: fileHost)
        return KFImage(url)
            .downloader(NetworkImageDownloader.downloader(for: fileHost))
            .setProcessor(LegacyRemoteImageProcessor() |> DownsamplingImageProcessor(size: CGSize(width: 50, height: 50)))
            .cacheOriginalImage()
            .cancelOnDisappear(true)
            .placeholder { avatarPlaceholder(for: conversation.kind) }
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 15))
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
            .font(.system(size: 22, weight: .medium))
            .foregroundColor(ClubTheme.darkTeal)
            .frame(width: 50, height: 50)
            .background(ClubTheme.pale)
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
