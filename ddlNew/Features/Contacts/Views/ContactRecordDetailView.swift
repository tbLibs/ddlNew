//
//  ContactRecordDetailView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import SwiftUI
import UIAdapter
import Combine
import AlertToast

/// 稳定UID资料页重新确认关系，编辑使用sheet，真实发消息继续push。
struct ContactRecordDetailView: View {
    @ObservedObject var store: ContactsStore
    @ObservedObject var businessStore: ContactsBusinessStore
    let contactID: String
    let fileHost: URL?
    let sourceGroupID: String?
    let applicationID: String?
    @Environment(\.contactChatNavigation) private var contactChatNavigation
    @State private var requestedChat: ChatRoute?
    @State private var groupAccessAllowed = false
    @State private var wasFriend = false
    @State private var refreshRevision = UUID()
    @ObservedObject private var groups = GroupsStore.shared
    @State private var editing = false
    @State private var moving = false
    @State private var sharing = false
    @State private var confirmingDelete = false
    @State private var confirmingBlack = false
    @State private var showingComplaint = false
    @State private var complaintSubmitted = false
    @State private var complaintFeedback: String?
    @State private var showingCopyToast = false
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
        ScrollView {
            VStack(spacing: 0) {
                if !groupAccessAllowed { EmptyClubState(title: "当前不可查看资料", message: "该群已限制私聊或成员资料访问。") }
                else if let contact {
                    if wasFriend && cachedContact == nil { Text("该好友已不在通讯录中").foregroundStyle(MessagingTheme.secondaryText) }
                    HStack(alignment: .center, spacing: 16.zoom()) {
                        ContactRecordAvatar(contact: contact, fileHost: fileHost, size: 72.zoom())
                        VStack(alignment: .leading, spacing: 8.zoom()) {
                            Text(contact.displayName).font(.title.weight(.bold)).foregroundStyle(MessagingTheme.text)
                            if !contact.isDeleted {
                                Button { copyAccount(contact) } label: {
                                    HStack(spacing: 6.zoom()) {
                                        Text("账号：" + (contact.account.isEmpty ? contact.id : contact.account)).font(.subheadline)
                                        Image(systemName: "doc.on.doc").font(.caption).accessibilityHidden(true)
                                    }.frame(minHeight: 44)
                                }.buttonStyle(.plain).foregroundStyle(MessagingTheme.secondaryText).accessibilityHint("复制公开账号")
                            }
                            if let role = businessStore.roleName(roleID: contact.roleID, isDeleted: contact.isDeleted) {
                                Text(role).font(.caption).foregroundStyle(MessagingTheme.accent)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(.vertical, 32.zoom())
                    MessagingTheme.divider.frame(height: 1)

                    Group {
                        VStack(alignment: .leading, spacing: 0) {
                            if contact.isDeleted { Text("该用户账号已注销").foregroundStyle(MessagingTheme.secondaryText).padding(16.zoom()) }
                            else {
                                if contact.nickname != contact.displayName { detail("昵称", value: contact.nickname) }
                                if let sourceGroupID, let nickname = businessStore.groupNickname(in: sourceGroupID, for: contactID), !nickname.isEmpty { detail("群昵称", value: nickname) }
                                if isFriend {
                                    // 旧版资料的备注整行可点击，打开同一份备注与描述草稿。
                                    Button { editing = true } label: {
                                        detail("备注", value: contact.remarks, showsDisclosure: true)
                                    }.buttonStyle(MessagingRowStyle()).disabled(businessStore.isSubmitting)
                                    Button { editing = true } label: {
                                        detail("描述", value: contact.description, showsDisclosure: true)
                                    }.buttonStyle(MessagingRowStyle()).disabled(businessStore.isSubmitting)
                                    detail("在线状态", value: contact.isOnline ? "在线" : "离线")
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if !businessStore.isLoading { EmptyClubState(title: "资料暂时不可用", message: "好友关系可能已变化，请刷新资料后重试。") }
            }.padding(.horizontal, 20.zoom()).padding(.bottom, 24.zoom())
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(MessagingTheme.surface)
        .safeAreaInset(edge: .bottom) {
            if groupAccessAllowed, let contact {
                VStack(spacing: 12.zoom()) {
                    if !contact.isDeleted, contact.id != businessStore.identity?.userUID {
                        if isFriend {
                            if contact.userType == 0, businessStore.blackStates[contactID] == true {
                                Text("你已将对方加入黑名单，请先移出黑名单再发送消息。").font(.footnote).foregroundStyle(MessagingTheme.secondaryText)
                            }
                            Button { sendMessage(to: contact) } label: {
                                Label("发消息", systemImage: "message.fill").frame(maxWidth: .infinity)
                            }.buttonStyle(MessagingActionButtonStyle()).disabled(contact.userType == 0 && contactID != "100002" && businessStore.blackStates[contactID] != false)
                        } else if permissions.current?.allows("allowAddFriend") == true {
                            applicationAction(contact)
                        }
                    }
                }.padding(.horizontal, 20.zoom()).padding(.vertical, 16.zoom())
                    .frame(maxWidth: 640).frame(maxWidth: .infinity).background(MessagingTheme.surface)
            }
        }
        .navigationTitle("用户资料")
        .modifier(MessagingPageChrome())
        .navigationDestination(isPresented: Binding(get: { requestedChat != nil }, set: { if !$0 { requestedChat = nil } })) {
            if let requestedChat { ChatRoomView(route: requestedChat) }
        }
        // 进入资料页的资料与黑名单查询静默加载，仅主动提交操作显示加载反馈。
        .messagingLoadingToast(businessStore.isSubmitting && !editing && !moving && !sharing && !showingComplaint)
        .messagingFeedbackToast(complaintFeedback ?? businessStore.errorMessage ?? businessStore.notice, isEnabled: !editing && !moving && !sharing && !showingComplaint)
        .toast(isPresenting: $showingCopyToast, duration: 2) {
            AlertToast(displayMode: .alert, type: .regular, title: "账号已复制",
                       style: .style(backgroundColor: MessagingTheme.toastBackground, titleColor: MessagingTheme.toastText))
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if groupAccessAllowed, let contact, isFriend, !contact.isDeleted, contact.id != businessStore.identity?.userUID {
                    Menu {
                        Button("移动到分组") { moving = true }
                        Button("推荐名片") { sharing = true }
                        if contact.userType == 0, contactID != "100002" {
                            Button("投诉与支持") { complaintFeedback = nil; showingComplaint = true }
                            if let blocked = businessStore.blackStates[contactID] {
                                Button(blocked ? "移出黑名单" : "加入黑名单", role: blocked ? nil : .destructive) {
                                    if blocked { Task { await businessStore.perform(.setBlack(friendID: contactID, blocked: false), sourceGroupID: sourceGroupID) } }
                                    else { confirmingBlack = true }
                                }
                            } else {
                                Button("重新确认黑名单状态") {
                                    Task {
                                        await businessStore.loadBlackState(contactID)
                                    }
                                }
                            }
                        }
                        Button("删除好友", role: .destructive) { confirmingDelete = true }
                    } label: {
                        Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44)
                    }.accessibilityLabel("好友管理").disabled(businessStore.isSubmitting)
                }
            }
        }
        .refreshable { await refreshProfile() }
        .task { await refreshProfile() }
        .onReceive(store.$contacts) { contacts in
            businessStore.reconcileContacts(contacts)
            if cachedContact != nil { wasFriend = true }
        }
        .onChange(of: businessStore.isSubmitting) { if $0 { complaintFeedback = nil } }
        .onChange(of: businessStore.errorMessage) { if $0 != nil { complaintFeedback = nil } }
        .onReceive(groups.$groups.dropFirst()) { _ in if sourceGroupID != nil { Task { await refreshProfile() } } }
        .onReceive(permissions.$current.dropFirst()) { _ in if sourceGroupID != nil { Task { await refreshProfile() } } }
        .sheet(isPresented: $editing) {
            if let contact {
                ContactRemarkEditor(businessStore: businessStore, contact: contact, sourceGroupID: sourceGroupID) {
                    let identity = businessStore.identity
                    await store.reload()
                    guard businessStore.identity == identity else { return }
                    businessStore.reconcileContacts(store.contacts)
                }
            }
        }
        .sheet(isPresented: $sharing) { if let contact { ContactsRecipientPickerView(content: .contact(contact, sourceGroupID: sourceGroupID)) } }
        .sheet(isPresented: $moving) { ContactGroupPicker(businessStore: businessStore, contactID: contactID, sourceGroupID: sourceGroupID) }
        .sheet(isPresented: $showingComplaint, onDismiss: {
            if complaintSubmitted { complaintFeedback = "投诉已提交"; complaintSubmitted = false }
        }) {
            ComplaintView(target: .user(contactID), targetName: contact?.displayName ?? "该用户", sourceGroupID: sourceGroupID) { complaintSubmitted = true }
        }
        .alert("加入黑名单？", isPresented: $confirmingBlack) {
            Button("取消", role: .cancel) {}
            Button("加入黑名单", role: .destructive) { Task { await businessStore.perform(.setBlack(friendID: contactID, blocked: true), sourceGroupID: sourceGroupID) } }
        } message: { Text("加入后将不再接收对方消息。你可以在这里或“我的—黑名单”中移出，好友和聊天记录会保留。") }
        .alert("删除好友？", isPresented: $confirmingDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { Task { await businessStore.perform(.deleteFriend(contactID), sourceGroupID: sourceGroupID); await store.reload() } }
        } message: { Text("成功删除将同时删除本机聊天记录，无法撤回。若需审核，资料与记录将保留到审核完成。") }
    }

    /// 聊天内由最近的聊天页返回/替换子页，通讯录等独立资料入口沿当前栈打开单聊。
    private func sendMessage(to contact: ContactRecord) {
        let target = ChatRoute(id: contact.id, kind: .single, title: contact.displayName, avatarURL: contact.avatar, sourceGroupID: sourceGroupID)
        if let contactChatNavigation { contactChatNavigation.open(target) }
        else { requestedChat = target }
    }

    /// 申请详情依据稳定申请身份和最新关系显示接受、等待或重新申请。
    @ViewBuilder private func applicationAction(_ contact: ContactRecord) -> some View {
        if businessStore.pendingApplicationIDs.contains(contactID) {
            Text("好友申请等待对方验证").foregroundStyle(MessagingTheme.secondaryText)
        } else if let userUID = businessStore.identity?.userUID,
           let application = businessStore.applications.first(where: { applicationID == nil ? $0.peerID(for: userUID) == contactID : $0.id == applicationID }) {
            switch application.action(for: userUID) {
            case .accept:
                Button { Task { await businessStore.perform(.accept(friendID: contact.id), sourceGroupID: sourceGroupID); await store.reload() } } label: { Text("通过验证").frame(maxWidth: .infinity) }.buttonStyle(MessagingActionButtonStyle()).disabled(businessStore.isSubmitting)
            case .waiting: Text("好友申请等待对方验证").foregroundStyle(MessagingTheme.secondaryText)
            case .reapply: requestButton("重新申请", contactID: contact.id)
            case .accepted, .expired: requestButton("添加好友", contactID: contact.id)
            case .unavailable: Text("该申请当前不可操作").foregroundStyle(MessagingTheme.secondaryText)
            }
        } else { requestButton("添加好友", contactID: contact.id) }
    }

    /// 提交仍需动态权限和服务器当前关系，申请发送不当作立即好友成功。
    private func requestButton(_ title: String, contactID: String) -> some View {
        Button { Task { await businessStore.perform(.apply(friendID: contactID), sourceGroupID: sourceGroupID) } } label: {
            Text(title).frame(maxWidth: .infinity)
        }.buttonStyle(MessagingActionButtonStyle()).disabled(businessStore.isSubmitting)
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
        if isFriend, contact?.userType == 0, contactID != businessStore.identity?.userUID { await businessStore.loadBlackState(contactID) }
    }

    /// 未设置字段明确占位，不展示服务端原始空值。
    private func detail(_ title: String, value: String, showsDisclosure: Bool = false) -> some View {
        HStack(spacing: 16.zoom()) {
            VStack(alignment: .leading, spacing: 8.zoom()) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(MessagingTheme.text)
                Text(value.isEmpty ? "未设置" : value).font(.subheadline).foregroundStyle(MessagingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if showsDisclosure {
                Image(systemName: "chevron.right").font(.subheadline).foregroundStyle(MessagingTheme.secondaryText).accessibilityHidden(true)
            }
        }.padding(.vertical, 20.zoom()).frame(minHeight: max(44, 72.zoom()))
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { MessagingTheme.divider.frame(height: 1) }

    }

    /// 复制当前展示的公开账号后短暂提示，不在资料底部追加状态文案。
    private func copyAccount(_ contact: ContactRecord) {
        UIPasteboard.general.string = contact.account.isEmpty ? contact.id : contact.account
        showingCopyToast = true
    }
}
