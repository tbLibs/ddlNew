//
//  ChatSettingsView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

struct ChatSettingsView: View {
    let route: ChatRoute
    @StateObject private var store = ChatRuntime.shared.makeSettingsStore()
    @ObservedObject private var groups = LoginSessionService.shared.groups
    @Environment(\.dismiss) private var dismiss
    @State private var showHistorySearch = false
    @State private var showAvatar = false
    @State private var showMembers = false
    @State private var selectedMemberProfile: ContactsRoute?
    @State private var showRemoveMembers = false
    @State private var pendingRemovalFeedback: String?
    @State private var feedback: String?
    @State private var showManagement = false
    @State private var showNotices = false
    @State private var showClear = false
    @State private var showLeave = false
    @State private var showDissolve = false
    @State private var editingName = false
    @State private var showNameEditor = false
    @State private var showInvite = false
    @State private var inviteReason = ""
    @State private var showCreateGroup = false
    @State private var showingComplaint = false
    @State private var complaintSubmitted = false
    @State private var createdRoute: ChatRoute?

    var body: some View {
        MessagingScroll {
            VStack(spacing: 12.zoom()) {
                if store.errorMessage != nil { Button("重新加载") { Task { await store.reload() } }.frame(minHeight: 44) }
                if let group = store.snapshot?.group {
                    MessagingCard {
                        VStack(spacing: 16.zoom()) {
                            Button { showAvatar = true } label: {
                                HStack(spacing: 12.zoom()) {
                                    ChatGroupMemberAvatar(member: ChatGroupMember(id: group.id, name: group.name, avatar: group.avatar, role: group.role, isDeleted: false), size: 56.zoom())
                                    VStack(alignment: .leading, spacing: 6.zoom()) { Text(group.name).font(.headline).foregroundStyle(MessagingTheme.text); Text("群资料").font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
                                    Spacer(); chevron
                                }.frame(minHeight: 56.zoom())
                            }.buttonStyle(MessagingRowStyle())
                            if group.membersSyncReady {
                                ChatGroupMemberPreview(group: group,
                                    onOpenProfile: { member in selectedMemberProfile = ContactsRoute(contactID: member.id, sourceGroupID: group.id) },
                                    onInvite: { showInvite = true }, onRemove: { feedback = nil; showRemoveMembers = true })
                            }
                            Button { showMembers = true } label: { row("查看群成员", value: canShowCount(group) ? "\(group.memberCount)人" : "") }.buttonStyle(MessagingRowStyle()).disabled(!group.membersSyncReady || !canOpenMembers(group))
                        }
                    }
                    MessagingCard(padding: 0) {
                        VStack(spacing: 0) {
                            if [1, 2].contains(group.role) { Button { editingName = true; showNameEditor = true } label: { row("群名称", value: group.name) }; separator }
                            if group.qrVisible || [1, 2].contains(group.role) { NavigationLink { BusinessQRCodeView(businessStore: LoginSessionService.shared.contactBusiness, groupID: group.id, title: group.name) } label: { row("群二维码", icon: "qrcode") }; separator }
                            Button { showNotices = true } label: { row("群公告") }
                            if [1, 2].contains(group.role) { separator; Button { showManagement = true } label: { row("群管理") } }
                        }.buttonStyle(MessagingRowStyle())
                    }
                } else if route.kind == .single && route.id != "100002" {
                    MessagingCard(padding: 0) {
                        VStack(spacing: 0) {
                            // 设置页沿当前子导航打开资料，避免值路由越过布尔设置目标且误关闭Store。
                            Button { selectedMemberProfile = ContactsRoute(contactID: route.id, sourceGroupID: route.sourceGroupID) } label: { row("查看好友资料") }
                            separator
                            Button { showCreateGroup = true } label: { row("添加好友创建群聊", icon: "person.badge.plus") }
                        }.buttonStyle(MessagingRowStyle())
                    }
                }
                MessagingCard(padding: 0) {
                    VStack(spacing: 0) {
                        Button { showHistorySearch = true } label: { row("查找聊天记录") }.buttonStyle(MessagingRowStyle())
                        separator
                        Toggle("置顶会话", isOn: Binding(get: { store.snapshot?.isPinned ?? false }, set: { value in Task { await store.setConversation(pinned: value) } })).padding(16.zoom()).frame(minHeight: 52.zoom())
                        if route.id != "100002" { separator; Toggle("消息免打扰", isOn: Binding(get: { store.snapshot?.isMuted ?? false }, set: { value in Task { await store.setConversation(muted: value) } })).padding(16.zoom()).frame(minHeight: 52.zoom()) }
                        if let group = store.snapshot?.group { separator; Button { editingName = false; showNameEditor = true } label: { row("我的群昵称", value: group.nickname) }.buttonStyle(MessagingRowStyle()) }
                    }
                }
                .disabled(store.snapshot == nil)
                if let group = store.snapshot?.group {
                    MessagingCard(padding: 0) { Button { feedback = nil; showingComplaint = true } label: { row("投诉与支持") }.buttonStyle(MessagingRowStyle()) }
                        .accessibilityHint("投诉群聊\(group.name)")
                }
                if store.snapshot?.group?.isPersonallyMuted == true { Text("你当前已被禁言").font(.footnote).foregroundStyle(MessagingTheme.secondaryText).frame(maxWidth: .infinity, alignment: .leading) }
                if store.snapshot?.canClear == true { MessagingCard(padding: 0) { Button("清空聊天记录", role: .destructive) { showClear = true }.frame(maxWidth: .infinity, minHeight: max(44, 52.zoom())).foregroundStyle(MessagingTheme.error).buttonStyle(MessagingRowStyle()) } }
                if let group = store.snapshot?.group {
                    if group.role == 2 { Text("群主退出前，请在群管理中先转让群主。").font(.footnote).foregroundStyle(MessagingTheme.secondaryText).frame(maxWidth: .infinity, alignment: .leading) }
                    MessagingCard(padding: 0) { Button(group.role == 2 ? "解散群聊" : "退出群聊", role: .destructive) { if group.role == 2 { showDissolve = true } else { showLeave = true } }.frame(maxWidth: .infinity, minHeight: max(44, 52.zoom())).foregroundStyle(MessagingTheme.error).buttonStyle(MessagingRowStyle()) }
                }
            }.padding(16.zoom())
        }
        .disabled(store.busy)
        .navigationTitle(route.kind == .group ? "群聊设置" : "聊天设置")
        .modifier(MessagingPageChrome())
        .messagingLoadingToast(store.busy && !presentingChild, title: "正在更新")
        .messagingFeedbackToast(store.errorMessage ?? feedback, isEnabled: !presentingChild)
        .task { if let context = ChatRuntime.shared.context(for: route) { await store.open(context) } }
        .onDisappear { store.leaveSettingsView(presentingChild: presentingChild) }
        .sheet(isPresented: $showHistorySearch) { if let context = ChatRuntime.shared.context(for: route) { NavigationStack { ChatHistorySearchView(context: context) { id in createdRoute = ChatRoute(id: route.id, kind: route.kind, title: route.title, avatarURL: route.avatarURL, targetMessageID: id) } } } }
        .navigationDestination(isPresented: $showAvatar) { ChatGroupAvatarView(route: route, store: store) }
        .navigationDestination(isPresented: $showMembers) { if let group = store.snapshot?.group { ChatGroupMembersView(group: group, store: store) } }
        .navigationDestination(isPresented: $showRemoveMembers) {
            ChatGroupRemovalView(store: store) { pendingRemovalFeedback = store.errorMessage ?? "成员移除成功" }
        }
        .onChange(of: showRemoveMembers) { showing in
            if !showing, let message = pendingRemovalFeedback { feedback = message; pendingRemovalFeedback = nil }
        }
        // 头像直接打开对应资料，保留来源群权限校验；返回时只回到当前群设置。
        .navigationDestination(isPresented: Binding(get: { selectedMemberProfile != nil }, set: { if !$0 { selectedMemberProfile = nil } })) {
            if let profile = selectedMemberProfile {
                ContactRecordDetailView(store: LoginSessionService.shared.contacts,
                    businessStore: LoginSessionService.shared.contactBusiness,
                    contactID: profile.contactID, fileHost: OSSConnectionBootstrap.shared.current?.getFileHost,
                    sourceGroupID: profile.sourceGroupID)
            }
        }
        .navigationDestination(isPresented: $showManagement) { if let group = store.snapshot?.group { ChatGroupManagementView(group: group, store: store) } }
        .navigationDestination(isPresented: $showNotices) { ChatGroupNoticesView(route: route) }
        .onChange(of: store.hasLeft) { if $0 { dismiss() } }
        .confirmationDialog("清空聊天记录", isPresented: $showClear, titleVisibility: .visible) { Button("清空当前会话记录", role: .destructive) { Task { await store.clear() } } } message: { Text("将申请清空当前聊天记录，不会删除好友关系或退出群聊。") }
        .confirmationDialog("退出群聊", isPresented: $showLeave, titleVisibility: .visible) { Button("退出并清理本机群记录", role: .destructive) { Task { await store.groupAction(.leave) } } } message: { Text("退出后将不能继续在此群发送消息。") }
        .confirmationDialog("解散群聊", isPresented: $showDissolve, titleVisibility: .visible) { Button("解散所有成员的群聊", role: .destructive) { Task { await store.groupAction(.dissolve) } } } message: { Text("群聊解散后，所有成员都不能继续使用此群。") }
        .sheet(isPresented: $showNameEditor) { ChatGroupNameEditor(store: store, editingName: editingName) }
        .sheet(isPresented: $showingComplaint, onDismiss: { if complaintSubmitted { feedback = "投诉已提交"; complaintSubmitted = false } }) {
            ComplaintView(target: .group(route.id), targetName: store.snapshot?.group?.name ?? route.title) { complaintSubmitted = true }
        }
        .sheet(isPresented: $showInvite) {
            GroupMemberPickerView(contacts: LoginSessionService.shared.contacts.contacts,
                excludedIDs: Set(store.snapshot?.group?.members.map(\.id) ?? []), minimum: 1, title: "邀请好友", invitationReason: store.snapshot?.group?.requiresApproval == true && store.snapshot?.group?.role == 0 ? $inviteReason : nil,
                recentIDs: LoginSessionService.shared.conversations.conversations.filter { $0.kind == .single }.map(\.id), friendGroups: LoginSessionService.shared.contactBusiness.groups,
                submissionError: store.errorMessage,
                onSubmit: { contacts in await store.groupAction(.invite(contacts.map { ChatGroupMember(id: $0.id, name: $0.displayName, avatar: $0.avatar, role: 0, isDeleted: $0.isDeleted) }, reason: store.snapshot?.group?.role == 0 ? inviteReason : "")) }, onConfirm: { _ in })
        }
        .sheet(isPresented: $showCreateGroup) {
            GroupMemberPickerView(contacts: LoginSessionService.shared.contacts.contacts, preselectedIDs: [route.id], minimum: 2,
                recentIDs: LoginSessionService.shared.conversations.conversations.filter { $0.kind == .single }.map(\.id), friendGroups: LoginSessionService.shared.contactBusiness.groups,
                submissionError: groups.errorMessage,
                onSubmit: { contacts in
                    guard let group = await groups.create(members: contacts, nickname: UserSessionStore.shared.currentUser?.nickname ?? "") else { return false }
                    createdRoute = ChatRoute(id: group.id, kind: .group, title: group.name, avatarURL: group.avatar)
                    return true
                }, onConfirm: { _ in })
        }
        .navigationDestination(isPresented: Binding(get: { createdRoute != nil }, set: { if !$0 { createdRoute = nil } })) { if let createdRoute { ChatRoomView(route: createdRoute) } }
    }

    /// 沿用旧版群安全权限：普通成员禁止私聊时不打开成员列表。
    private func canOpenMembers(_ group: ChatGroupDetail) -> Bool {
        [1, 2].contains(group.role) || !group.isPrivateChat || UserRoleAuthorityStore.shared.current?.allows("groupSecurity") == true
    }

    private var presentingChild: Bool { showAvatar || showMembers || showRemoveMembers || selectedMemberProfile != nil || showManagement || showNotices || showInvite || showCreateGroup || showHistorySearch || showNameEditor || showingComplaint }

    private var chevron: some View { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(MessagingTheme.secondaryText).accessibilityHidden(true) }
    private var separator: some View { Rectangle().fill(MessagingTheme.divider).frame(height: 1).padding(.leading, 16.zoom()) }

    /// 分区行保留系统导航语义，数值按用户字号自适应换行。
    private func row(_ title: String, value: String = "", icon: String? = nil) -> some View {
        HStack(spacing: 12.zoom()) { Text(title).foregroundStyle(MessagingTheme.text); Spacer(minLength: 8.zoom()); if !value.isEmpty { Text(value).font(.subheadline).foregroundStyle(MessagingTheme.secondaryText).multilineTextAlignment(.trailing) }; if let icon { Image(systemName: icon).foregroundStyle(MessagingTheme.secondaryText).accessibilityHidden(true) }; chevron }.padding(16.zoom()).frame(minHeight: max(44, 52.zoom())).contentShape(Rectangle())
    }

    /// 人数角色开关独立于群成员资料访问权限。
    private func canShowCount(_ group: ChatGroupDetail) -> Bool {
        let authority = UserRoleAuthorityStore.shared.current
        return authority?.allows("showGroupPersonNum") == true || [1, 2].contains(group.role) || !LocalMessagingSettings.onlyAdminsViewGroupPersonCount
    }
}

/// 与旧版群名称/我的群昵称独立编辑页一致，保存失败保留输入。
private struct ChatGroupNameEditor: View {
    @ObservedObject var store: ChatSettingsStore
    let editingName: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var original = ""
    @State private var confirmDiscard = false
    @FocusState private var focused: Bool
    private var canSave: Bool { !store.busy && valid && input != original }
    private var valid: Bool { editingName ? !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : input.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count <= 30 }

    var body: some View {
        NavigationStack {
            MessagingScroll {
                VStack(alignment: .leading, spacing: 12.zoom()) {
                    Text(editingName ? "群名称" : "我的群昵称")
                        .font(.footnote)
                        .foregroundStyle(MessagingTheme.secondaryText)
                    MessagingCard {
                        TextField(
                            editingName ? "输入群名称" : "输入群昵称",
                            text: $input,
                            axis: .vertical
                        )
                        .focused($focused)
                        .submitLabel(.done)
                        .accessibilityLabel(editingName ? "群名称" : "我的群昵称")
                        .frame(minHeight: 44)
                    }
                    if !editingName {
                        Text("最多30字")
                            .font(.footnote)
                            .foregroundStyle(
                                valid ? MessagingTheme.secondaryText : MessagingTheme.error
                            )
                    }
                }.padding(16.zoom())
            }
            .navigationTitle(editingName ? "修改群名称" : "我的群昵称").modifier(MessagingPageChrome())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        if input != original { confirmDiscard = true } else {
                            dismiss()
                        }
                    }
                    .disabled(store.busy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            if await store
                                .groupAction(editingName ? .rename(input) : .nickname(input)) {
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(
                        canSave ? MessagingTheme.primaryAction : MessagingTheme.secondaryText
                    )
                    .frame(minHeight: 44)
                    .disabled(!canSave)
                }
            }
        }
        .messagingLoadingToast(store.busy, title: "正在保存")
        .messagingFeedbackToast(store.errorMessage)
        .interactiveDismissDisabled(store.busy || input != original)
            .onAppear { original = editingName ? store.snapshot?.group?.name ?? "" : store.snapshot?.group?.nickname ?? ""; input = original; focused = true }
            .confirmationDialog("放弃本次修改？", isPresented: $confirmDiscard, titleVisibility: .visible) { Button("放弃修改", role: .destructive) { dismiss() } }
    }
}
