//
//  ContactsView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

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
    @State private var createdRoute: ChatRoute?
    @State private var openGroups = Set<String>()
    @Environment(\.layoutDirection) private var layoutDirection
    @FocusState private var searchFocused: Bool

    private var sections: [ContactSection] { ContactSorter.sections(from: store.contacts, matching: query) }

    var body: some View {
        ScrollViewReader { proxy in
        ClubScroll {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    ScreenHeading(eyebrow: "一起发现，一起参与", title: "通讯录")
                    Spacer(minLength: 8)
                    NavigationLink(value: ContactsPageRoute.globalSearch) { Image(systemName: "magnifyingglass").frame(width: 44, height: 44) }.accessibilityLabel("全局搜索")
                    if permissions.current?.allows("allowAddFriend") == true {
                        NavigationLink(value: ContactsPageRoute.addFriend) {
                            Image(systemName: "person.badge.plus").frame(width: 44, height: 44)
                        }.accessibilityLabel("添加好友")
                    }
                }
                ClubCard(padding: 18, highlighted: true) {
                    HStack(spacing: 14) {
                        ClubIcon(name: "contacts", size: 26).foregroundStyle(ClubTheme.darkTeal).frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("我的好友").font(.headline)
                            Text("\(store.contacts.count) 位好友").font(.subheadline).foregroundStyle(ClubTheme.secondary).accessibilityIdentifier("contactsCount")
                        }
                        Spacer(); if store.isSyncing { ProgressView().accessibilityLabel("正在同步好友") }
                    }
                }
                HStack {
                    NavigationLink(value: ContactsPageRoute.newFriends) {
                        Label("新朋友", systemImage: "person.crop.circle.badge.plus")
                        if businessStore.unreadCount > 0 { Text(businessStore.unreadCount > 99 ? "99+" : "\(businessStore.unreadCount)").font(.caption.bold()).foregroundStyle(ClubTheme.error) }
                    }
                    Spacer()
                    if permissions.current?.allows("isShowFileAssistant") == true {
                        NavigationLink(value: ChatRoute(id: "100002", kind: .single, title: "文件助手", avatarURL: "")) { Label("文件助手", systemImage: "folder") }
                    }
                }.font(.subheadline)
                NavigationLink(value: ContactsPageRoute.groupAssistant) { Label("群助手", systemImage: "person.2.badge.gearshape") }.font(.subheadline)
                CommunitySearchField(placeholder: filter == .groups ? "搜索群名称" : "搜索备注、昵称、账号", text: $query, focus: $searchFocused, identifier: "contactSearch")
                CommunityFilters(selection: $filter)
                if filter == .friends, layoutDirection == .leftToRight, !sections.isEmpty {
                    Menu("按字母定位") { ForEach(sections) { section in Button(section.id) { proxy.scrollTo("contact.section.\(section.id)", anchor: .top) } } }
                }
                content
                if let error = store.errorMessage { Text(error).font(.subheadline).foregroundStyle(ClubTheme.error) }
                if let error = businessStore.errorMessage { Text(error).font(.subheadline).foregroundStyle(ClubTheme.error) }
                if let error = groupsStore.errorMessage { Text(error).font(.subheadline).foregroundStyle(ClubTheme.error) }
            }.padding(.horizontal, 20).padding(.top, 18)
        }
        }
        .modifier(ClubKeyboardDismissal(isFocused: searchFocused) { searchFocused = false })
        .task { await store.reload(); await businessStore.reload(); await groupsStore.reload() }
        .sheet(isPresented: $managingGroups) { FriendGroupManagerView(businessStore: businessStore) }
        .sheet(isPresented: $selectingMembers) {
            GroupMemberPickerView(contacts: store.contacts,
                                  recentIDs: LoginSessionService.shared.conversations.conversations.filter { $0.kind == .single }.map(\.id),
                                  friendGroups: businessStore.groups, submissionError: groupsStore.errorMessage,
                                  onSubmit: { members in
                guard let group = await groupsStore.create(members: members, nickname: UserSessionStore.shared.currentUser?.nickname ?? "") else { return false }
                createdRoute = ChatRoute(id: group.id, kind: .group, title: group.name, avatarURL: group.avatar)
                return true
            }, onConfirm: { _ in })
        }
        .navigationDestination(isPresented: Binding(get: { createdRoute != nil }, set: { if !$0 { createdRoute = nil } })) {
            if let createdRoute { ChatRoomView(route: createdRoute) }
        }
    }

    /// 三种列表分别读取好友、业务分组和群库，不用演示数据填充空态。
    @ViewBuilder private var content: some View {
        switch filter {
        case .friends:
            if sections.isEmpty {
                if store.isSyncing { ProgressView("正在同步好友") }
                else if store.errorMessage == nil {
                    EmptyClubState(title: query.isEmpty ? "暂无好友" : "没有找到相关好友", message: "添加好友后，可在这里查看真实好友资料。")
                        .accessibilityIdentifier("contactsEmptyState")
                }
            }
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.id).font(.caption.weight(.semibold)).foregroundStyle(ClubTheme.secondary).accessibilityAddTraits(.isHeader)
                    ClubCard(padding: 0) { LazyVStack(spacing: 0) { ForEach(section.contacts) { contact in contactLink(contact) } } }
                }.id("contact.section.\(section.id)")
            }
        case .friendGroups:
            Button("管理好友分组") { managingGroups = true }.buttonStyle(.bordered)
            if businessStore.groups.isEmpty {
                if businessStore.isLoading { ProgressView("正在加载好友分组") }
                else if businessStore.errorMessage == nil { EmptyClubState(title: "暂无好友分组", message: "可创建分组来整理好友。") }
            }
            ForEach(businessStore.groups) { group in
                ClubCard(padding: 0) {
                    VStack(spacing: 0) {
                        Button { toggleGroup(group.id) } label: {
                            HStack { Text(group.name).font(.headline); Text("\(group.members.count)").foregroundStyle(ClubTheme.secondary); Spacer(); Image(systemName: openGroups.contains(group.id) ? "chevron.down" : "chevron.right").accessibilityHidden(true) }.padding(16)
                        }.buttonStyle(.plain).accessibilityLabel("\(group.name)，\(group.members.count)位好友")
                        if openGroups.contains(group.id) { ForEach(group.members.filter { query.isEmpty || $0.searchText.localizedCaseInsensitiveContains(query) }) { contact in contactLink(contact) } }
                    }
                }
            }
        case .groups:
            if permissions.current?.allows("createGroup") == true {
                Button("创建群聊") { selectingMembers = true }.buttonStyle(.bordered).disabled(groupsStore.isCreating)
            }
            if groupsStore.isCreating { ProgressView("正在创建群聊") }
            let visible = groupsStore.groups.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            if visible.isEmpty {
                if groupsStore.isLoading { ProgressView("正在加载群聊") }
                else if groupsStore.errorMessage == nil { EmptyClubState(title: query.isEmpty ? "暂无群聊" : "没有找到群聊", message: "加入或创建群聊后，将在这里显示。") }
            }
            ForEach(visible) { group in
                NavigationLink(value: ChatRoute(id: group.id, kind: .group, title: group.name, avatarURL: group.avatar)) {
                    ClubCard { HStack { GroupRecordAvatar(group: group, fileHost: fileHost); Text(group.name).foregroundStyle(ClubTheme.ink); Spacer(); Image(systemName: "chevron.right").accessibilityHidden(true) } }
                }.buttonStyle(.plain)
            }
        }
    }

    /// 展开状态只按分组ID保存，刷新或改名后不会影响其他分组。
    private func toggleGroup(_ id: String) { if openGroups.contains(id) { openGroups.remove(id) } else { openGroups.insert(id) } }

    /// 每个好友行携带稳定UID路由，避免打开后使用旧快照操作。
    private func contactLink(_ contact: ContactRecord) -> some View {
        NavigationLink(value: ContactsRoute(contactID: contact.id)) {
            HStack(spacing: 14) {
                ContactRecordAvatar(contact: contact, fileHost: fileHost, size: 48)
                VStack(alignment: .leading, spacing: 6) {
                    Text(contact.displayName).font(.body.weight(.semibold)).foregroundStyle(ClubTheme.ink).lineLimit(1)
                    if let role = businessStore.roleName(roleID: contact.roleID, isDeleted: contact.isDeleted) { Text(role).font(.caption.bold()).foregroundStyle(ClubTheme.darkTeal) }
                    if !contact.isDeleted { Text(contact.account.isEmpty ? contact.id : contact.account).font(.subheadline).foregroundStyle(ClubTheme.secondary).lineLimit(1) }
                }
                Spacer(); if contact.isOnline && !contact.isDeleted { Circle().fill(ClubTheme.darkTeal).frame(width: 7, height: 7).accessibilityLabel("在线") }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(ClubTheme.secondary).accessibilityHidden(true)
            }.padding(16).contentShape(Rectangle())
        }.buttonStyle(CommunityRowStyle()).accessibilityIdentifier("contact.\(contact.id)")
    }
}
