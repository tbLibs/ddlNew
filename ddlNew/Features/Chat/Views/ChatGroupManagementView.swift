//
//  ChatGroupManagementView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI
import UIAdapter

struct ChatGroupManagementView: View {
    let group: ChatGroupDetail
    @ObservedObject var store: ChatSettingsStore
    @State private var feedback: String?
    private var current: ChatGroupDetail { store.snapshot?.group ?? group }

    var body: some View {
        MessagingScroll {
            VStack(alignment: .leading, spacing: 12.zoom()) {
                if ![1, 2].contains(current.role) || !current.isActive {
                    MessagingCard { Label("群管理权限已被收回", systemImage: "lock.fill").foregroundStyle(MessagingTheme.secondaryText) }
                } else {
                    Text("成员管理").font(.footnote).foregroundStyle(MessagingTheme.secondaryText)
                    MessagingCard(padding: 0) {
                        VStack(spacing: 0) {
                            NavigationLink { ChatGroupMembersView(group: current, store: store) } label: { navigationRow("成员禁言与角色管理", icon: "person.2") }
                            divider
                            NavigationLink { GroupApplicationsView(groupID: current.id) } label: { navigationRow("入群申请", icon: "person.badge.plus") }
                        }.buttonStyle(MessagingRowStyle())
                    }
                    Text("群设置").font(.footnote).foregroundStyle(MessagingTheme.secondaryText)
                    MessagingCard(padding: 0) {
                        VStack(spacing: 0) {
                            groupToggle("全员禁言", value: current.isAllMuted, action: ChatGroupAction.muteAll); divider
                            groupToggle("禁止成员私聊", value: current.isPrivateChat, action: ChatGroupAction.privateChat); divider
                            groupToggle("进群需审核", value: current.requiresApproval, action: ChatGroupAction.approval); divider
                            groupToggle("新成员查看历史", value: current.historyVisible, action: ChatGroupAction.history); divider
                            groupToggle("显示群二维码", value: current.qrVisible, action: ChatGroupAction.qr); divider
                            groupToggle("禁止群音视频通话", value: current.isNetCall, action: ChatGroupAction.prohibitCalls); divider
                            groupToggle("群提示", value: current.remindEnabled, action: ChatGroupAction.remind)
                        }
                    }
                    Text("当前禁言成员").font(.footnote).foregroundStyle(MessagingTheme.secondaryText)
                    MessagingCard {
                        VStack(alignment: .leading, spacing: 12.zoom()) {
                            if current.bannedMembers.isEmpty { Text("当前没有单独禁言的成员").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText) }
                            ForEach(current.bannedMembers) { member in
                                HStack(spacing: 12.zoom()) {
                                    if let target = current.members.first(where: { $0.id == member.id }) { ChatGroupMemberAvatar(member: target, size: 40.zoom()) }
                                    VStack(alignment: .leading, spacing: 4.zoom()) { Text(member.name).font(.subheadline); Text(member.statusText).font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
                                    Spacer()
                                    if let target = current.members.first(where: { $0.id == member.id }), target.role < current.role {
                                        Button("解除禁言") { Task { feedback = nil; if await store.groupAction(.muteMembers([member.id], minutes: 0)), store.errorMessage == nil { feedback = "已解除禁言" } } }.font(.subheadline).frame(minHeight: 44).disabled(store.busy)
                                    }
                                }
                            }
                        }
                    }
                }
                if let error = store.errorMessage { Text(error).font(.footnote).foregroundStyle(MessagingTheme.error) }
                if let feedback { Text(feedback).font(.footnote).foregroundStyle(MessagingTheme.accent).accessibilityLabel(feedback) }
            }.padding(16.zoom())
        }
        .disabled(store.busy)
        .overlay { if store.busy { ProgressView("正在更新").padding().background(MessagingTheme.surface, in: RoundedRectangle(cornerRadius: 10.zoom())) } }
        .navigationTitle("群管理").modifier(MessagingPageChrome())
    }

    private var divider: some View { Rectangle().fill(MessagingTheme.divider).frame(height: 1).padding(.leading, 16.zoom()) }

    /// 与旧群管理页一致，成员操作在前，群策略按独立白色分区展示。
    private func navigationRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 12.zoom()) { Image(systemName: icon).foregroundStyle(MessagingTheme.accent).accessibilityHidden(true); Text(title); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(MessagingTheme.secondaryText).accessibilityHidden(true) }.padding(16.zoom()).frame(minHeight: max(44, 52.zoom())).contentShape(Rectangle())
    }

    /// 请求回读后才变化，失败显示旧值并保留错误，避免开关假成功。
    private func groupToggle(_ title: String, value: Bool, action: @escaping (Bool) -> ChatGroupAction) -> some View {
        Toggle(title, isOn: Binding(get: { value }, set: { enabled in Task { feedback = nil; if await store.groupAction(action(enabled)), store.errorMessage == nil { feedback = "已更新" + title } } })).padding(16.zoom()).frame(minHeight: max(44, 52.zoom()))
    }
}
