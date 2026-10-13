//
//  ChatSettingsView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

struct ChatSettingsView: View {
    let route: ChatRoute
    @StateObject private var store = ChatRuntime.shared.makeSettingsStore()
    @ObservedObject private var groups = LoginSessionService.shared.groups
    @Environment(\.dismiss) private var dismiss
    @State private var showHistorySearch = false
    @State private var showAvatar = false
    @State private var showMembers = false
    @State private var showManagement = false
    @State private var showNotices = false
    @State private var showClear = false
    @State private var showLeave = false
    @State private var showDissolve = false
    @State private var name = ""
    @State private var nickname = ""
    @State private var showInvite = false
    @State private var inviteReason = ""
    @State private var showCreateGroup = false
    @State private var createdRoute: ChatRoute?

    var body: some View {
        Form {
            if let error = store.errorMessage { Section { Text(error).foregroundStyle(.red); Button("刷新") { Task { await store.reload() } } } }
            Section {
                Button("查找聊天记录") { showHistorySearch = true }
                if route.kind == .single && route.id != "100002" { NavigationLink("查看好友资料", value: ContactsRoute(contactID: route.id, sourceGroupID: route.sourceGroupID)); Button("添加好友创建群聊") { showCreateGroup = true } }
                Toggle("置顶会话", isOn: Binding(get: { store.snapshot?.isPinned ?? false }, set: { value in Task { await store.setConversation(pinned: value) } }))
                if route.id != "100002" { Toggle("消息免打扰", isOn: Binding(get: { store.snapshot?.isMuted ?? false }, set: { value in Task { await store.setConversation(muted: value) } })) }
            }
            if let group = store.snapshot?.group {
                Section("群资料") {
                    LabeledContent("群名称", value: group.name)
                    Button("群头像") { showAvatar = true }
                    if canShowCount(group) { LabeledContent("群成员", value: "\(group.memberCount)人") }
                    if group.qrVisible || [1, 2].contains(group.role) { NavigationLink("群二维码") { BusinessQRCodeView(businessStore: LoginSessionService.shared.contactBusiness, groupID: group.id, title: group.name) } }
                    if group.membersSyncReady { ChatGroupMemberPreview(group: group, onInvite: { showInvite = true }, onRemove: { showMembers = true }) }
                    Button("群成员") { showMembers = true }.disabled(!group.membersSyncReady)
                    if group.isPersonallyMuted { Text("你当前已被禁言").foregroundStyle(.secondary) }
                    if group.requiresApproval { TextField("邀请审核说明", text: $inviteReason).accessibilityLabel("邀请审核说明") }
                    Button("邀请好友") { showInvite = true }
                    TextField("我的群昵称（最多30字）", text: $nickname).accessibilityLabel("我的群昵称")
                    Button("保存群昵称") { Task { await store.groupAction(.nickname(nickname)) } }.disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines) == group.nickname)
                    if [1, 2].contains(group.role) {
                        TextField("群名称", text: $name).accessibilityLabel("群名称")
                        Button("保存群名称") { Task { await store.groupAction(.rename(name)) } }
                    }
                    Button("群公告") { showNotices = true }
                    if [1, 2].contains(group.role) { Button("群管理") { showManagement = true } }
                }
                Section {
                    if group.role == 2 { Text("群主退出前，请在群管理中先转让群主。") .foregroundStyle(.secondary); Button("解散群聊", role: .destructive) { showDissolve = true } }
                    else { Button("退出群聊", role: .destructive) { showLeave = true } }
                }
            }
            if store.snapshot?.canClear == true { Section { Button("清空聊天记录", role: .destructive) { showClear = true } } }
        }
        .disabled(store.busy)
        .overlay { if store.busy { ProgressView() } }
        .navigationTitle("聊天设置").navigationBarTitleDisplayMode(.inline)
        .task { if let context = ChatRuntime.shared.context(for: route) { await store.open(context); name = store.snapshot?.group?.name ?? ""; nickname = store.snapshot?.group?.nickname ?? "" } }
        .onDisappear { store.leaveSettingsView(presentingChild: showAvatar || showMembers || showManagement || showNotices || showInvite || showCreateGroup || showHistorySearch) }
        .sheet(isPresented: $showHistorySearch) { if let context = ChatRuntime.shared.context(for: route) { NavigationStack { ChatHistorySearchView(context: context) { id in createdRoute = ChatRoute(id: route.id, kind: route.kind, title: route.title, avatarURL: route.avatarURL, targetMessageID: id) } } } }
        .navigationDestination(isPresented: $showAvatar) { ChatGroupAvatarView(route: route, store: store) }
        .navigationDestination(isPresented: $showMembers) { if let group = store.snapshot?.group { ChatGroupMembersView(group: group, store: store) } }
        .navigationDestination(isPresented: $showManagement) { if let group = store.snapshot?.group { ChatGroupManagementView(group: group, store: store) } }
        .navigationDestination(isPresented: $showNotices) { ChatGroupNoticesView(route: route) }
        .onChange(of: store.hasLeft) { if $0 { dismiss() } }
        .confirmationDialog("清空聊天记录", isPresented: $showClear, titleVisibility: .visible) { Button("清空当前会话记录", role: .destructive) { Task { await store.clear() } } } message: { Text("将申请清空当前聊天记录，不会删除好友关系或退出群聊。") }
        .confirmationDialog("退出群聊", isPresented: $showLeave, titleVisibility: .visible) { Button("退出并清理本机群记录", role: .destructive) { Task { await store.groupAction(.leave) } } } message: { Text("退出后将不能继续在此群发送消息。") }
        .confirmationDialog("解散群聊", isPresented: $showDissolve, titleVisibility: .visible) { Button("解散所有成员的群聊", role: .destructive) { Task { await store.groupAction(.dissolve) } } } message: { Text("群聊解散后，所有成员都不能继续使用此群。") }
        .sheet(isPresented: $showInvite) {
            GroupMemberPickerView(contacts: LoginSessionService.shared.contacts.contacts,
                excludedIDs: Set(store.snapshot?.group?.members.map(\.id) ?? []), minimum: 1,
                submissionError: store.errorMessage,
                onSubmit: { contacts in await store.groupAction(.invite(contacts.map { ChatGroupMember(id: $0.id, name: $0.displayName, avatar: $0.avatar, role: 0, isDeleted: $0.isDeleted) }, reason: inviteReason)) }, onConfirm: { _ in })
        }
        .sheet(isPresented: $showCreateGroup) {
            GroupMemberPickerView(contacts: LoginSessionService.shared.contacts.contacts, preselectedIDs: [route.id], minimum: 2,
                submissionError: groups.errorMessage,
                onSubmit: { contacts in
                    guard let group = await groups.create(members: contacts, nickname: UserSessionStore.shared.currentUser?.nickname ?? "") else { return false }
                    createdRoute = ChatRoute(id: group.id, kind: .group, title: group.name, avatarURL: group.avatar)
                    return true
                }, onConfirm: { _ in })
        }
        .navigationDestination(isPresented: Binding(get: { createdRoute != nil }, set: { if !$0 { createdRoute = nil } })) { if let createdRoute { ChatRoomView(route: createdRoute) } }
    }

    /// 人数角色开关独立于群成员资料访问权限。
    private func canShowCount(_ group: ChatGroupDetail) -> Bool {
        let authority = UserRoleAuthorityStore.shared.current
        let config = OSSConnectionBootstrap.shared.current.flatMap { SystemConfigStore.shared.load(apiHost: $0.apiHost) }
        return authority?.allows("showGroupPersonNum") == true || [1, 2].contains(group.role) || config?.onlyAllowAdminViewGroupPersonCount == "0"
    }
}
