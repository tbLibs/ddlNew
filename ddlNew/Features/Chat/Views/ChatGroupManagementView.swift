//
//  ChatGroupManagementView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

struct ChatGroupManagementView: View {
    let group: ChatGroupDetail
    @ObservedObject var store: ChatSettingsStore
    private var current: ChatGroupDetail { store.snapshot?.group ?? group }

    var body: some View {
        Form {
            if ![1, 2].contains(current.role) || !current.isActive { Text("群管理权限已被收回").foregroundStyle(.secondary) }
            else {
                Section("群策略") {
                    groupToggle("全员禁言", value: current.isAllMuted, action: ChatGroupAction.muteAll)
                    groupToggle("禁止成员私聊", value: current.isPrivateChat, action: ChatGroupAction.privateChat)
                    groupToggle("进群需审核", value: current.requiresApproval, action: ChatGroupAction.approval)
                    groupToggle("新成员查看历史", value: current.historyVisible, action: ChatGroupAction.history)
                    groupToggle("显示群二维码", value: current.qrVisible, action: ChatGroupAction.qr)
                    groupToggle("禁止群音视频通话", value: current.isNetCall, action: ChatGroupAction.prohibitCalls)
                    groupToggle("群提示", value: current.remindEnabled, action: ChatGroupAction.remind)
                }
                Section("当前禁言成员") {
                    if current.bannedMembers.isEmpty { Text("当前没有单独禁言的成员").foregroundStyle(.secondary) }
                    ForEach(current.bannedMembers) { member in
                        VStack(alignment: .leading, spacing: 6) { Text(member.name); Text(member.statusText).font(.caption).foregroundStyle(.secondary)
                            if let target = current.members.first(where: { $0.id == member.id }), target.role < current.role { Button("解除禁言") { Task { await store.groupAction(.muteMembers([member.id], minutes: 0)) } } }
                        }
                    }
                }
                Section {
                    NavigationLink("成员禁言与角色管理") { ChatGroupMembersView(group: current, store: store) }
                    NavigationLink("入群申请") { GroupApplicationsView(groupID: current.id) }
                }
            }
            if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
        }
        .disabled(store.busy)
        .navigationTitle("群管理")
    }

    /// 每次切换真实请求并回读，失败不会留下仅本机生效的新值。
    private func groupToggle(_ title: String, value: Bool, action: @escaping (Bool) -> ChatGroupAction) -> some View {
        Toggle(title, isOn: Binding(get: { value }, set: { enabled in Task { await store.groupAction(action(enabled)) } }))
    }
}
