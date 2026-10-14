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

    private var current: ChatGroupDetail { store.snapshot?.group ?? group }
    private var canOpenProfiles: Bool { [1, 2].contains(current.role) || !current.isPrivateChat || UserRoleAuthorityStore.shared.current?.allows("groupSecurity") == true }
    private var members: [ChatGroupMember] { current.members.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) } }

    var body: some View {
        List {
            MessagingSearchField(placeholder: "搜索群成员", text: $query, focus: $searchFocused, identifier: "groupMembers.search").listRowBackground(MessagingTheme.background).listRowSeparator(.hidden)
            if let feedback { Text(feedback).font(.footnote).foregroundStyle(MessagingTheme.accent).listRowBackground(MessagingTheme.surface) }
            if members.isEmpty && !store.busy { Text(query.isEmpty ? "暂无群成员" : "无搜索结果").foregroundStyle(MessagingTheme.secondaryText).frame(maxWidth: .infinity, minHeight: 80.zoom()).listRowBackground(MessagingTheme.surface) }
            if let error = store.errorMessage { Section { Text(error).foregroundStyle(MessagingTheme.error); Button("刷新成员和权限") { Task { await store.reload() } }.frame(minWidth: 44, minHeight: 44).disabled(store.busy) } }
            ForEach(members) { member in
                HStack(spacing: 12.zoom()) {
                    ChatGroupMemberAvatar(member: member, size: 44.zoom())
                    if canOpenProfiles && !member.isDeleted && member.id != UserSessionStore.shared.currentUser?.userUID { NavigationLink(value: ContactsRoute(contactID: member.id, sourceGroupID: current.id)) { memberLabel(member) } }
                    else { memberLabel(member) }
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
                        }.frame(minWidth: 44, minHeight: 44).disabled(store.busy)
                    }
                }.frame(minHeight: max(44, 60.zoom())).listRowBackground(MessagingTheme.surface)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
        .modifier(MessagingPageChrome())
        .navigationTitle("群成员")
        .sheet(isPresented: Binding(get: { if case .remove = confirmation { return true }; return false }, set: { if !$0 { confirmation = nil } })) {
            NavigationStack { Form { Text("移除成员：" + targetName); Toggle("同时删除该成员的群消息", isOn: $deleteMessages); if let error = store.errorMessage { Text(error).foregroundStyle(MessagingTheme.error) } }
                .navigationTitle("移除成员").modifier(MessagingPageChrome()).toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { confirmation = nil }.disabled(store.busy) }; ToolbarItem(placement: .confirmationAction) { Button("移除", role: .destructive) { if case .remove(let ids, _) = confirmation { Task { if await store.groupAction(.remove(ids, deleteMessages: deleteMessages)) { feedback = "已移除成员"; confirmation = nil } } } }.disabled(store.busy) } }.interactiveDismissDisabled(store.busy)
            }
        }
        .confirmationDialog("确认对\(targetName)的群操作", isPresented: Binding(get: { if case .remove = confirmation { return false }; return confirmation != nil }, set: { if !$0 { confirmation = nil } }), titleVisibility: .visible) {
            if let action = confirmation { Button("确认", role: .destructive) { Task { feedback = nil; if await store.groupAction(action), store.errorMessage == nil { feedback = "群操作已完成" } }; confirmation = nil } }
        } message: { Text("此操作将提交服务器，权限或成员状态变化可能导致失败。转让群主成功后你的群主权限将被收回。") }
    }
    /// 名称、角色、禁言状态放在同一信息列，大字号不会挤压操作入口。
    private func memberLabel(_ member: ChatGroupMember) -> some View {
        VStack(alignment: .leading, spacing: 4.zoom()) {
            Text(member.name).foregroundStyle(MessagingTheme.text)
            if member.isDeleted { Text("已注销").font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
            if member.role == 2 { Text("群主").font(.caption).foregroundStyle(MessagingTheme.accent) }
            if member.role == 1 { Text("管理员").font(.caption).foregroundStyle(MessagingTheme.accent) }
            if current.bannedMembers.contains(where: { $0.id == member.id }) { Text("已禁言").font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
        }
    }

    /// 禁言菜单使用旧版按小时/天/月的可读时长，协议仍提交分钟。
    private func muteTitle(_ minutes: Int) -> String {
        switch minutes { case 10: return "禁言10分钟"; case 60: return "禁言1小时"; case 720: return "禁言12小时"; case 1440: return "禁言1天"; case 10080: return "禁言7天"; case 43200: return "禁言30天"; default: return "永久禁言" }
    }

}
