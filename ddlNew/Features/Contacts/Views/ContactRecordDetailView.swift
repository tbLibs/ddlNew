//
//  ContactRecordDetailView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import SwiftUI
import Combine

/// 稳定UID资料页重新确认关系，编辑使用sheet，真实发消息继续push。
struct ContactRecordDetailView: View {
    @ObservedObject var store: ContactsStore
    @ObservedObject var businessStore: ContactsBusinessStore
    let contactID: String
    let fileHost: URL?
    let sourceGroupID: String?
    let applicationID: String?
    @State private var groupAccessAllowed = false
    @State private var wasFriend = false
    @State private var refreshRevision = UUID()
    @ObservedObject private var groups = GroupsStore.shared
    @State private var editing = false
    @State private var moving = false
    @State private var sharing = false
    @State private var confirmingDelete = false
    @ObservedObject private var permissions = UserRoleAuthorityStore.shared

    private var cachedContact: ContactRecord? { store.contacts.first { $0.id == contactID } }
    private var contact: ContactRecord? { cachedContact ?? businessStore.profiles[contactID] }
    private var isFriend: Bool { cachedContact != nil && (businessStore.profiles[contactID] == nil || businessStore.friendIDs.contains(contactID)) }

    /// 稳定路由参数保留群来源，sheet不能丢失访问限制。
    init(store: ContactsStore, businessStore: ContactsBusinessStore, contactID: String, fileHost: URL?, sourceGroupID: String? = nil, applicationID: String? = nil) {
        self.store = store; self.businessStore = businessStore; self.contactID = contactID; self.fileHost = fileHost; self.sourceGroupID = sourceGroupID; self.applicationID = applicationID
        _groupAccessAllowed = State(initialValue: sourceGroupID == nil)
    }

    var body: some View {
        ClubScroll {
            VStack(spacing: 20) {
                if !groupAccessAllowed { EmptyClubState(title: "当前不可查看资料", message: "该群已限制私聊或成员资料访问。") }
                else if let contact {
                    if wasFriend && cachedContact == nil { Text("该好友已不在通讯录中").foregroundStyle(ClubTheme.secondary) }
                    ContactRecordAvatar(contact: contact, fileHost: fileHost, size: 88).padding(.top, 24)
                    Text(contact.displayName).font(.title2.bold())
                    if let role = businessStore.roleName(roleID: contact.roleID, isDeleted: contact.isDeleted) { Text(role).font(.caption.bold()).foregroundStyle(ClubTheme.darkTeal) }
                    ClubCard {
                        VStack(alignment: .leading, spacing: 16) {
                            if contact.isDeleted { Text("该用户账号已注销").foregroundStyle(ClubTheme.secondary) }
                            else {
                                detail("账号", value: contact.account)
                                detail("昵称", value: contact.nickname)
                                if let sourceGroupID, let nickname = businessStore.groupNickname(in: sourceGroupID, for: contactID), !nickname.isEmpty { detail("群昵称", value: nickname) }
                                if isFriend {
                                    detail("备注", value: contact.remarks)
                                    detail("描述", value: contact.description)
                                    detail("在线状态", value: contact.isOnline ? "在线" : "离线")
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !contact.isDeleted, contact.id != businessStore.identity?.userUID {
                        if isFriend {
                            NavigationLink(value: ChatRoute(id: contact.id, kind: .single, title: contact.displayName, avatarURL: contact.avatar, sourceGroupID: sourceGroupID)) {
                                Label("发消息", systemImage: "message.fill").frame(maxWidth: .infinity).padding(14)
                            }.buttonStyle(.borderedProminent).tint(HomeTheme.forest)
                            Button("备注与描述") { editing = true }.buttonStyle(.bordered)
                            Button("移动到分组") { moving = true }.buttonStyle(.bordered)
                            Button("推荐名片") { sharing = true }.buttonStyle(.bordered)
                            Button("删除好友", role: .destructive) { confirmingDelete = true }.disabled(businessStore.isSubmitting)
                        } else if permissions.current?.allows("allowAddFriend") == true {
                            applicationAction(contact)
                        }
                    }
                } else if businessStore.isLoading { ProgressView("正在读取资料") }
                else { EmptyClubState(title: "资料暂时不可用", message: "好友关系可能已变化，请刷新资料后重试。") }
                if let error = businessStore.errorMessage { Text(error).foregroundStyle(ClubTheme.error) }
                if let notice = businessStore.notice { Text(notice).foregroundStyle(ClubTheme.secondary) }
            }.padding(24)
        }
        .navigationTitle("用户资料").navigationBarTitleDisplayMode(.inline).navigationBarHidden(false)
        .task { await refreshProfile() }
        .onReceive(store.$contacts) { contacts in
            businessStore.reconcileContacts(contacts)
            if cachedContact != nil { wasFriend = true }
        }
        .onReceive(groups.$groups.dropFirst()) { _ in if sourceGroupID != nil { Task { await refreshProfile() } } }
        .onReceive(permissions.$current.dropFirst()) { _ in if sourceGroupID != nil { Task { await refreshProfile() } } }
        .sheet(isPresented: $editing) { if let contact { ContactRemarkEditor(businessStore: businessStore, contact: contact, sourceGroupID: sourceGroupID) } }
        .sheet(isPresented: $sharing) { if let contact { ContactsRecipientPickerView(content: .contact(contact, sourceGroupID: sourceGroupID)) } }
        .sheet(isPresented: $moving) { ContactGroupPicker(businessStore: businessStore, contactID: contactID, sourceGroupID: sourceGroupID) }
        .alert("删除好友？", isPresented: $confirmingDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { Task { await businessStore.perform(.deleteFriend(contactID), sourceGroupID: sourceGroupID); await store.reload() } }
        } message: { Text("成功删除将同时删除本机聊天记录，无法撤回。若需审核，资料与记录将保留到审核完成。") }
    }

    /// 申请详情依据稳定申请身份和最新关系显示接受、等待或重新申请。
    @ViewBuilder private func applicationAction(_ contact: ContactRecord) -> some View {
        if let userUID = businessStore.identity?.userUID,
           let application = businessStore.applications.first(where: { applicationID == nil ? $0.peerID(for: userUID) == contactID : $0.id == applicationID }) {
            switch application.action(for: userUID) {
            case .accept:
                Button("接受申请") { Task { await businessStore.perform(.accept(friendID: contact.id), sourceGroupID: sourceGroupID); await store.reload() } }.buttonStyle(.borderedProminent).tint(HomeTheme.forest).disabled(businessStore.isSubmitting)
            case .waiting: Text("好友申请等待对方验证").foregroundStyle(ClubTheme.secondary)
            case .reapply: requestButton("重新申请", contactID: contact.id)
            case .accepted, .expired: requestButton("添加好友", contactID: contact.id)
            case .unavailable: Text("该申请当前不可操作").foregroundStyle(ClubTheme.secondary)
            }
        } else { requestButton("添加好友", contactID: contact.id) }
    }

    /// 提交仍需动态权限和服务器当前关系，申请发送不当作立即好友成功。
    private func requestButton(_ title: String, contactID: String) -> some View {
        Button(title) { Task { await businessStore.perform(.apply(friendID: contactID), sourceGroupID: sourceGroupID) } }
            .buttonStyle(.borderedProminent).tint(HomeTheme.forest).disabled(businessStore.isSubmitting)
    }

    /// 先确认来源群访问，再读取用户资料；缓存更新立即反映删除与注销。
    private func refreshProfile() async {
        let revision = UUID(); refreshRevision = revision
        let allowed = await businessStore.checkGroupAccess(sourceGroupID)
        guard refreshRevision == revision else { return }
        groupAccessAllowed = allowed
        guard groupAccessAllowed else { return }
        await businessStore.loadProfile(contactID, sourceGroupID: sourceGroupID)
        await store.reload()
        guard refreshRevision == revision else { return }
        if isFriend { wasFriend = true }
    }

    /// 未设置字段明确占位，不展示服务端原始空值。
    private func detail(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(ClubTheme.secondary)
            Text(value.isEmpty ? "未设置" : value).font(.body).foregroundStyle(ClubTheme.ink)
        }
    }
}
