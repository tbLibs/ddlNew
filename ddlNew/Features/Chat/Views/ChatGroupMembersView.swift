//
//  ChatGroupMembersView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

struct ChatGroupMembersView: View {
    let group: ChatGroupDetail
    @ObservedObject var store: ChatSettingsStore
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var feedback: String?
    @State private var confirmation: ChatGroupAction?
    @State private var targetName = ""
    @State private var deleteMessages = false

    private var showingRemoval: Bool { if case .remove = confirmation { return true }; return false }
    private var current: ChatGroupDetail { store.snapshot?.group ?? group }
    private var canOpenProfiles: Bool { [1, 2].contains(current.role) || !current.isPrivateChat || UserRoleAuthorityStore.shared.current?.allows("groupSecurity") == true }
    private var members: [ChatGroupMember] { current.members.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) } }

    var body: some View {
        List {
            MessagingSearchField(placeholder: "搜索群成员", text: $query, focus: $searchFocused, identifier: "groupMembers.search").listRowBackground(MessagingTheme.background).listRowSeparator(.hidden)
            if members.isEmpty && !store.busy { Text(query.isEmpty ? "暂无群成员" : "无搜索结果").foregroundStyle(MessagingTheme.secondaryText).frame(maxWidth: .infinity, minHeight: 80.zoom()).listRowBackground(MessagingTheme.surface) }
            if store.errorMessage != nil { Section { Button("刷新成员和权限") { Task { await store.reload() } }.frame(minWidth: 44, minHeight: 44).disabled(store.busy) } }
            ForEach(members) { member in
                Group {
                    if canOpenProfiles && !member.isDeleted && member.role != 3 {
                        // 群设置和成员页由布尔目标push；资料沿当前栈继续push，避免值路由重排父目标。
                        NavigationLink {
                            ContactRecordDetailView(store: LoginSessionService.shared.contacts,
                                businessStore: LoginSessionService.shared.contactBusiness,
                                contactID: member.id, fileHost: OSSConnectionBootstrap.shared.current?.getFileHost,
                                sourceGroupID: current.id)
                        } label: { memberRow(member) }
                    } else { memberRow(member) }
                }.listRowBackground(MessagingTheme.surface)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
        .modifier(MessagingPageChrome())
        .navigationTitle("群成员")
        .messagingLoadingToast(store.busy && !showingRemoval, title: "正在更新群成员")
        .messagingFeedbackToast(store.errorMessage ?? feedback, isEnabled: !showingRemoval)
        .sheet(isPresented: Binding(get: { if case .remove = confirmation { return true }; return false }, set: { if !$0 { confirmation = nil } })) {
            NavigationStack { Form { Text("移除成员：" + targetName); Toggle("同时删除该成员的群消息", isOn: $deleteMessages) }
                .navigationTitle("移除成员").modifier(MessagingPageChrome()).toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { confirmation = nil }.disabled(store.busy) }; ToolbarItem(placement: .confirmationAction) { Button("移除", role: .destructive) { if case .remove(let ids, _) = confirmation { Task { feedback = nil; if await store.groupAction(.remove(ids, deleteMessages: deleteMessages)) { feedback = "已移除成员"; confirmation = nil } } } }.disabled(store.busy) } }.messagingLoadingToast(store.busy, title: "正在移除成员").messagingFeedbackToast(store.errorMessage).interactiveDismissDisabled(store.busy)
            }
        }
        .confirmationDialog("确认对\(targetName)的群操作", isPresented: Binding(get: { if case .remove = confirmation { return false }; return confirmation != nil }, set: { if !$0 && !showingRemoval { confirmation = nil } }), titleVisibility: .visible) {
            if let action = confirmation { Button("确认", role: .destructive) { Task { feedback = nil; if await store.groupAction(action), store.errorMessage == nil { feedback = "群操作已完成" } }; confirmation = nil } }
        } message: { Text("此操作将提交服务器，权限或成员状态变化可能导致失败。转让群主成功后你的群主权限将被收回。") }
    }
    /// 系统资料箭头位于整行右边，管理菜单点击不触发资料跳转。
    private func memberRow(_ member: ChatGroupMember) -> some View {
                HStack(spacing: 12.zoom()) {
                    ChatGroupMemberAvatar(member: member, size: 44.zoom())
                    memberLabel(member)
                    Spacer()
                    if [1, 2].contains(current.role) && !member.isDeleted && member.id != UserSessionStore.shared.currentUser?.userUID && member.role < current.role {
                        Menu("管理") {
                            Button("移除成员", role: .destructive) { targetName = member.name; deleteMessages = false; confirmation = .remove([member.id], deleteMessages: false) }
                            ForEach([10, 60, 720, 1440, 10080, 43200, -1], id: \.self) { minutes in
                                Button(muteTitle(minutes)) { targetName = member.name; confirmation = .muteMembers([member.id], minutes: minutes) }
                            }
                            Button("解除禁言") { targetName = member.name; confirmation = .muteMembers([member.id], minutes: 0) }
                            if current.role == 2 {
                                Button(member.role == 1 ? "取消管理员" : "设置管理员") { targetName = member.name; confirmation = .setManagers([member.id], enabled: member.role != 1) }
                                Button("转让群主") { targetName = member.name; confirmation = .transferOwner(member.id) }
                            }
                        }.buttonStyle(.borderless).frame(minWidth: 44, minHeight: 44).disabled(store.busy)
                    }
                }.frame(minHeight: max(44, 60.zoom()))
    }

    /// 名称、角色、禁言状态放在同一信息列，大字号不会挤压操作入口。
    private func memberLabel(_ member: ChatGroupMember) -> some View {
        VStack(alignment: .leading, spacing: 4.zoom()) {
            Text(member.name).foregroundStyle(MessagingTheme.text)
            if member.isDeleted { Text("已注销").font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
            ChatGroupMemberRoleBadge(member: member)
            if current.bannedMembers.contains(where: { $0.id == member.id }) { Text("已禁言").font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
        }
    }

    /// 禁言菜单使用旧版按小时/天/月的可读时长，协议仍提交分钟。
    private func muteTitle(_ minutes: Int) -> String {
        switch minutes { case 10: return "禁言10分钟"; case 60: return "禁言1小时"; case 720: return "禁言12小时"; case 1440: return "禁言1天"; case 10080: return "禁言7天"; case 43200: return "禁言30天"; default: return "永久禁言" }
    }

}
