//
//  ChatGroupMembersView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

struct ChatGroupMembersView: View {
    let group: ChatGroupDetail
    @ObservedObject var store: ChatSettingsStore
    @State private var query = ""
    @State private var confirmation: ChatGroupAction?
    @State private var targetName = ""
    @State private var deleteMessages = false

    private var current: ChatGroupDetail { store.snapshot?.group ?? group }
    private var canOpenProfiles: Bool { [1, 2].contains(current.role) || !current.isPrivateChat || UserRoleAuthorityStore.shared.current?.allows("groupSecurity") == true }
    private var members: [ChatGroupMember] { current.members.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) } }

    var body: some View {
        List {
            if let error = store.errorMessage { Section { Text(error).foregroundStyle(.red); Button("刷新成员和权限") { Task { await store.reload() } }.disabled(store.busy) } }
            ForEach(members) { member in
                HStack {
                    if canOpenProfiles && member.id != UserSessionStore.shared.currentUser?.userUID { NavigationLink(member.name, value: ContactsRoute(contactID: member.id, sourceGroupID: current.id)) }
                    else { Text(member.name) }
                    Spacer()
                    if member.role == 2 { Text("群主").font(.caption).foregroundStyle(.secondary) }
                    if member.role == 1 { Text("管理员").font(.caption).foregroundStyle(.secondary) }
                    if current.bannedMembers.contains(where: { $0.id == member.id }) { Text("已禁言").font(.caption).foregroundStyle(.secondary) }
                    if [1, 2].contains(current.role) && member.id != UserSessionStore.shared.currentUser?.userUID && member.role < current.role {
                        Menu("管理") {
                            Button("移除成员", role: .destructive) { targetName = member.name; deleteMessages = false; confirmation = .remove([member.id], deleteMessages: false) }
                            ForEach([10, 60, 720, 1440, 10080, 43200, -1], id: \.self) { minutes in
                                Button(minutes == -1 ? "永久禁言" : "禁言\(minutes)分钟") { targetName = member.name; confirmation = .muteMembers([member.id], minutes: minutes) }
                            }
                            Button("解除禁言") { targetName = member.name; confirmation = .muteMembers([member.id], minutes: 0) }
                            if current.role == 2 {
                                Button(member.role == 1 ? "取消管理员" : "设置管理员") { targetName = member.name; confirmation = .setManagers([member.id], enabled: member.role != 1) }
                                Button("转让群主") { targetName = member.name; confirmation = .transferOwner(member.id) }
                            }
                        }.disabled(store.busy)
                    }
                }.frame(minHeight: 44)
            }
        }
        .searchable(text: $query, prompt: "搜索群成员")
        .navigationTitle("群成员")
        .sheet(isPresented: Binding(get: { if case .remove = confirmation { return true }; return false }, set: { if !$0 { confirmation = nil } })) {
            NavigationStack { Form { Text("移除成员：" + targetName); Toggle("同时删除该成员的群消息", isOn: $deleteMessages); if let error = store.errorMessage { Text(error).foregroundStyle(.red) } }
                .navigationTitle("移除成员").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { confirmation = nil }.disabled(store.busy) }; ToolbarItem(placement: .confirmationAction) { Button("移除", role: .destructive) { if case .remove(let ids, _) = confirmation { Task { if await store.groupAction(.remove(ids, deleteMessages: deleteMessages)) { confirmation = nil } } } }.disabled(store.busy) } }.interactiveDismissDisabled(store.busy)
            }
        }
        .confirmationDialog("确认对\(targetName)的群操作", isPresented: Binding(get: { if case .remove = confirmation { return false }; return confirmation != nil }, set: { if !$0 { confirmation = nil } }), titleVisibility: .visible) {
            if let action = confirmation { Button("确认", role: .destructive) { Task { await store.groupAction(action) }; confirmation = nil } }
        } message: { Text("此操作将提交服务器，权限或成员状态变化可能导致失败。转让群主成功后你的群主权限将被收回。") }
    }
}
