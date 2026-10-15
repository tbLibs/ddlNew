//
//  ContactsView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI
import UIAdapter

/// 真实通讯录保留好友缓存所有者，新增分组、群列表与业务入口。
struct ContactsView: View {
    @ObservedObject var store: ContactsStore
    @ObservedObject var businessStore: ContactsBusinessStore
    @ObservedObject var groupsStore: GroupsStore
    let fileHost: URL?
    @ObservedObject private var permissions = UserRoleAuthorityStore.shared
    @State private var query = ""
    @State private var filter: ContactsListFilter = .friends
    @State private var managingGroups = false
    @State private var selectingMembers = false
    @EnvironmentObject private var navigation: ActivityNavigation
    @State private var openGroups = Set<String>()
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @FocusState private var searchFocused: Bool

    private var sections: [ContactSection] { ContactSorter.sections(from: store.contacts, matching: query) }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0.zoom()) {
                header
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0.zoom(), pinnedViews: [.sectionHeaders]) {
                        shortcuts.padding(.horizontal, 12.zoom()).padding(.vertical, 12.zoom())
                        Section {
                            content
                        } header: {
                            VStack(spacing: 8.zoom()) {
                                VStack(alignment: .leading, spacing: 4.zoom()) {
                                HStack(spacing: 8.zoom()) {
                                    MessagingTabs(selection: $filter)
                                    if store.isSyncing { ProgressView().accessibilityLabel("正在同步好友") }
                                    if !dynamicTypeSize.isAccessibilitySize { contactsCount }
                                }
                                if dynamicTypeSize.isAccessibilitySize {
                                    HStack {
                                        contactsCount
                                        Spacer(minLength: 8)
                                        if filter == .friends && !sections.isEmpty { letterIndex(proxy: proxy) }
                                    }
                                }
                                }
                                MessagingSearchField(placeholder: filter == .groups ? "搜索群名称" : "搜索备注、昵称、账号",
                                                     text: $query, focus: $searchFocused, identifier: "contactSearch")
                            }.padding(.horizontal, 16.zoom()).padding(.bottom, 12.zoom()).background(MessagingTheme.background)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable { await store.reload(); await businessStore.reload(); await groupsStore.reload() }
                .overlay(alignment: .trailing) {
                    if filter == .friends, layoutDirection == .leftToRight, !sections.isEmpty, !dynamicTypeSize.isAccessibilitySize {
                        letterIndex(proxy: proxy)
                    }
                }
            }
            .frame(maxWidth: 720).frame(maxWidth: .infinity)
            .background(MessagingTheme.background.ignoresSafeArea())
        }
        .tint(MessagingTheme.accent)
        .messagingLoadingToast(!selectingMembers && ((filter == .groups && (groupsStore.isLoading || groupsStore.isCreating)) || (filter == .friendGroups && businessStore.isLoading)))
        .messagingFeedbackToast(groupsStore.errorMessage ?? businessStore.errorMessage ?? store.errorMessage, isEnabled: !selectingMembers && !managingGroups)
        .modifier(ClubKeyboardDismissal(isFocused: searchFocused, tint: MessagingTheme.accent, background: MessagingTheme.surface) { searchFocused = false })
        .task { await store.reload(); await businessStore.reload(); await groupsStore.reload() }
        .sheet(isPresented: $managingGroups) { FriendGroupManagerView(businessStore: businessStore) }
        .sheet(isPresented: $selectingMembers) {
            GroupMemberPickerView(contacts: store.contacts,
                                  recentIDs: LoginSessionService.shared.conversations.conversations.filter { $0.kind == .single }.map(\.id),
                                  friendGroups: businessStore.groups, submissionError: groupsStore.errorMessage,
                                  onSubmit: { members in
                guard let group = await groupsStore.create(members: members, nickname: UserSessionStore.shared.currentUser?.nickname ?? "") else { return false }
                navigation.open(ChatRoute(id: group.id, kind: .group, title: group.name, avatarURL: group.avatar))
                return true
            }, onConfirm: { _ in })
        }

    }

    /// 紧凑页头固定在安全区域内，搜索和添加均保留44pt点击范围。
    private var header: some View {
        HStack(spacing: 8.zoom()) {
            Text("通讯录").font(.headline).foregroundStyle(MessagingTheme.text).accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            NavigationLink(value: ContactsPageRoute.globalSearch) {
                Image(systemName: "magnifyingglass").font(.system(size: 22.zoom())).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
            }.accessibilityLabel("全局搜索")
            if permissions.current?.allows("allowAddFriend") == true {
                NavigationLink(value: ContactsPageRoute.addFriend) {
                    Image(systemName: "plus.circle").font(.system(size: 22.zoom())).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
                }.accessibilityLabel("添加好友")
            }
        }.foregroundStyle(MessagingTheme.text).padding(.horizontal, 16.zoom()).padding(.vertical, 4.zoom())
    }

    /// 数量在大字号下独立一行，不挤压三个分类按钮。
    private var contactsCount: some View {
        Text("\(store.contacts.count) 位好友").font(.caption).foregroundStyle(MessagingTheme.secondaryText)
            .accessibilityIdentifier("contactsCount")
    }

    /// 文件助手按实时权限显示，其余入口在同一行均分空间。
    private var shortcuts: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8.zoom())) : AnyLayout(HStackLayout(spacing: 12.zoom()))
        return layout {
            NavigationLink(value: ContactsPageRoute.newFriends) {
                ContactShortcut(title: "新朋友", symbol: "person.crop.circle.badge.plus", unreadCount: businessStore.unreadCount)
            }
            if permissions.current?.allows("isShowFileAssistant") == true {
                NavigationLink(value: ChatRoute(id: "100002", kind: .single, title: "文件助手", avatarURL: "")) {
                    ContactShortcut(title: "文件助手", symbol: "folder")
                }
            }
            NavigationLink(value: ContactsPageRoute.groupAssistant) {
                ContactShortcut(title: "群助手", symbol: "bubble.left.and.bubble.right")
            }
        }.buttonStyle(.plain)
    }

    /// 字母索引可直接点击，也提供完整菜单供大字号与VoiceOver定位。
    private func letterIndex(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 4.zoom()) {
            if !dynamicTypeSize.isAccessibilitySize && verticalSizeClass != .compact {
                VStack(spacing: 4.zoom()) {
                    ForEach(sections) { section in
                        Text(section.id).font(.system(size: 11.zoom(), weight: .semibold)).frame(height: 13.zoom()).accessibilityHidden(true)
                    }
                }
                .frame(width: max(44, 44.zoom())).padding(.vertical, 8.zoom())
                .background(MessagingTheme.surface.opacity(0.95), in: Capsule())
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let index = min(max(Int((value.location.y - 8.zoom()) / (13.zoom() + 4.zoom())), 0), sections.count - 1)
                    proxy.scrollTo("contact.section.\(sections[index].id)", anchor: .center)
                })
                .accessibilityHidden(true)
            }
            Menu {
                ForEach(sections) { section in
                    Button(section.id) { proxy.scrollTo("contact.section.\(section.id)", anchor: .center) }
                }
            } label: {
                Image(systemName: "list.bullet").font(.system(size: 18.zoom())).frame(width: max(44, 44.zoom()), height: max(44, 44.zoom()))
                    .background(MessagingTheme.surface, in: Circle())
            }.accessibilityLabel("按字母定位好友")
        }.foregroundStyle(MessagingTheme.accent).padding(.trailing, 2.zoom())
    }

    /// 三种列表分别读取好友、业务分组和群库，不用演示数据填充空态。
    @ViewBuilder private var content: some View {
        switch filter {
        case .friends:
            if sections.isEmpty {
                if store.isSyncing { ProgressView("正在同步好友").padding(16.zoom()) }
                else if store.errorMessage == nil {
                    emptyState(query.isEmpty ? "暂无好友" : "没有找到相关好友", detail: "添加好友后，可在这里查看好友资料。")
                        .accessibilityIdentifier("contactsEmptyState")
                }
            }
            ForEach(sections) { section in
                Text(section.id).font(.caption.weight(.semibold)).foregroundStyle(MessagingTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16.zoom()).padding(.vertical, 6.zoom())
                    .background(MessagingTheme.background).accessibilityAddTraits(.isHeader)
                    .id("contact.section.\(section.id)")
                ForEach(section.contacts) { contact in contactLink(contact) }
            }
        case .friendGroups:
            Button { managingGroups = true } label: {
                Label("管理好友分组", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity, minHeight: 48.zoom(), alignment: .leading).padding(.horizontal, 16.zoom())
            }.buttonStyle(MessagingRowStyle())
            if businessStore.groups.isEmpty {
                if !businessStore.isLoading && businessStore.errorMessage == nil { emptyState("暂无好友分组", detail: "可创建分组来整理好友。") }
            }
            ForEach(businessStore.groups) { group in
                Button { toggleGroup(group.id) } label: {
                    HStack(spacing: 12.zoom()) {
                        Image(systemName: openGroups.contains(group.id) ? "chevron.down" : "chevron.right").font(.caption).accessibilityHidden(true)
                        Text(group.displayName).foregroundStyle(MessagingTheme.text)
                        Spacer()
                        Text("\(group.members.count)").foregroundStyle(MessagingTheme.secondaryText)
                    }.padding(.horizontal, 16.zoom()).frame(minHeight: 54.zoom())
                }.buttonStyle(MessagingRowStyle()).accessibilityLabel("\(group.displayName)，\(group.members.count)位好友")
                    .accessibilityValue(openGroups.contains(group.id) ? "已展开" : "已收起")
                if openGroups.contains(group.id) {
                    ForEach(group.members.filter { query.isEmpty || $0.searchText.localizedCaseInsensitiveContains(query) }) { contact in contactLink(contact) }
                }
            }
        case .groups:
            if permissions.current?.allows("createGroup") == true {
                Button { selectingMembers = true } label: {
                    Label("创建群聊", systemImage: "person.2.badge.plus").frame(maxWidth: .infinity, minHeight: 48.zoom(), alignment: .leading).padding(.horizontal, 16.zoom())
                }.buttonStyle(MessagingRowStyle()).disabled(groupsStore.isCreating)
            }
            let visible = groupsStore.groups.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            if visible.isEmpty {
                if !groupsStore.isLoading && groupsStore.errorMessage == nil { emptyState(query.isEmpty ? "暂无群聊" : "没有找到群聊", detail: "加入或创建群聊后，将在这里显示。") }
            }
            ForEach(visible) { group in
                NavigationLink(value: ChatRoute(id: group.id, kind: .group, title: group.name, avatarURL: group.avatar)) {
                    HStack(spacing: 12.zoom()) {
                        GroupRecordAvatar(group: group, fileHost: fileHost)
                        Text(group.name).foregroundStyle(MessagingTheme.text).lineLimit(2)
                        Spacer(minLength: 8)
                        Text("\(group.memberCount)人").font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                    }.padding(.horizontal, 16.zoom()).padding(.vertical, 10.zoom()).frame(maxWidth: .infinity, minHeight: 68.zoom(), alignment: .leading)
                }.buttonStyle(MessagingRowStyle())
            }
        }
    }

    /// 空态使用中性排版，真实数据为空时仍说明下一步操作。
    private func emptyState(_ title: String, detail: String) -> some View {
        VStack(spacing: 12.zoom()) {
            Text(title).font(.headline).foregroundStyle(MessagingTheme.text)
            Text(detail).font(.subheadline).foregroundStyle(MessagingTheme.secondaryText).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.horizontal, 24.zoom()).padding(.vertical, 48.zoom())
    }

    /// 展开状态只按分组ID保存，刷新或改名后不会影响其他分组。
    private func toggleGroup(_ id: String) { if openGroups.contains(id) { openGroups.remove(id) } else { openGroups.insert(id) } }

    /// 路由保持稳定UID，展示快照变化时重建导航标签，避免跨分区移动后沿用旧备注正文。
    private func contactLink(_ contact: ContactRecord) -> some View {
        let roleName = businessStore.roleName(roleID: contact.roleID, isDeleted: contact.isDeleted)
        let presentationIdentity = ContactRowPresentationIdentity(contact: contact, fileHost: fileHost, roleName: roleName)
        return NavigationLink(value: ContactsRoute(contactID: contact.id)) {
            HStack(spacing: 12.zoom()) {
                ContactRecordAvatar(contact: contact, fileHost: fileHost, size: 50.zoom())
                    .overlay(alignment: .topTrailing) {
                        if contact.isOnline && !contact.isDeleted {
                            Circle().fill(MessagingTheme.online).frame(width: 8.zoom(), height: 8.zoom())
                                .overlay(Circle().stroke(MessagingTheme.surface, lineWidth: 1)).accessibilityHidden(true)
                        }
                    }
                VStack(alignment: .leading, spacing: 4.zoom()) {
                    Text(contact.displayName).font(.body).foregroundStyle(MessagingTheme.text).lineLimit(2)
                    if let roleName {
                        Text(roleName).font(.caption).foregroundStyle(MessagingTheme.accent)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 16.zoom()).padding(.trailing, filter == .friends ? 48.zoom() : 16.zoom().zoom()).padding(.vertical, 9.zoom()).frame(maxWidth: .infinity, minHeight: 68.zoom(), alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { MessagingTheme.divider.frame(height: 0.5).padding(.leading, 78.zoom()) }
        }
        .buttonStyle(MessagingRowStyle())
        .id(presentationIdentity)
        .accessibilityIdentifier("contact.\(contact.id)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(contact.displayName + (contact.isDeleted ? "，账号已注销" : contact.isOnline ? "，在线" : "，离线"))
    }
}
