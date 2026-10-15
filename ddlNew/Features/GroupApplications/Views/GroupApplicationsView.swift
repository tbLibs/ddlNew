//
//  GroupApplicationsView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//
import SwiftUI
import Combine
import UIAdapter

/// 群助手和单群共用页面，好友申请不复用群审核协议。
struct GroupApplicationsView: View {
    let groupID: String?
    @StateObject private var store = GroupApplicationsStore(client: SDKGroupApplicationsClient())
    @ObservedObject private var session = UserSessionStore.shared
    @ObservedObject private var conversations = LoginSessionService.shared.conversations
    @State private var filter = GroupApplicationFilter.all
    private var pendingOnly: Bool { filter == .pending }
    private var allSelected: Bool { let ids = Set(store.records.filter { $0.status == 1 }.map(\.id)); return !ids.isEmpty && ids.isSubset(of: store.selectedIDs) }
    @ObservedObject private var groups = GroupsStore.shared
    @ObservedObject private var businessStore = ContactsBusinessStore.shared
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    @State private var profileRoute: ContactsRoute?
    @State private var confirmation: Bool?
    @Environment(\.scenePhase) private var scenePhase

    /// 无群ID表示全局群通知，有群ID表示本群管理审核。
    init(groupID: String? = nil) { self.groupID = groupID }

    var body: some View {
        List {
            if store.records.isEmpty && !store.isLoading && store.errorMessage == nil { VStack(spacing: 12.zoom()) { Image(systemName: "person.badge.plus").font(.largeTitle).accessibilityHidden(true); Text(pendingOnly ? "暂无待审核申请" : "暂无群通知") }.foregroundStyle(MessagingTheme.secondaryText).frame(maxWidth: .infinity, minHeight: 180.zoom()).listRowBackground(MessagingTheme.background).listRowSeparator(.hidden) }
            ForEach(store.records) { record in applicationRow(record).listRowBackground(MessagingTheme.surface) }
            if store.hasMore && !store.isLoading { Button("加载更多") { Task { await store.loadMore() } }.frame(minHeight: 44) }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .top, spacing: 0) { MessagingTabs(selection: $filter).padding(.horizontal, 16.zoom()).background(MessagingTheme.surface).disabled(store.isReviewing) }
        .modifier(MessagingPageChrome())
        .messagingFeedbackToast(store.errorMessage ?? store.notice)
        .messagingLoadingToast(store.isLoading || store.isReviewing, title: "正在处理")
        .navigationTitle(groupID == nil ? "群通知" : "入群审核")
        .navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
        .refreshable { await store.reload(pendingOnly: pendingOnly) }
        .safeAreaInset(edge: .bottom) {
            if pendingOnly && !store.records.isEmpty {
                VStack(spacing: 8.zoom()) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12.zoom()) { selectAllButton; Spacer(minLength: 0); reviewButtons }
                        VStack(spacing: 8.zoom()) { selectAllButton; HStack(spacing: 12.zoom()) { reviewButtons } }
                    }
                }.padding(16.zoom()).background(MessagingTheme.surface).overlay(alignment: .top) { Rectangle().fill(MessagingTheme.divider).frame(height: 1) }
                    .disabled(store.isReviewing)
            }
        }
        .confirmationDialog(confirmation == true ? "同意所选入群申请？" : "拒绝所选入群申请？",
            isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }), titleVisibility: .visible) {
                Button(confirmation == true ? "同意" : "拒绝", role: confirmation == true ? nil : .destructive) {
                    if let accept = confirmation { Task { await store.review(accept: accept) } }
                    confirmation = nil
                }
                Button("取消", role: .cancel) { confirmation = nil }
        }
        .task {
            if let uid = session.currentUser?.userUID, store.records.isEmpty { store.prepare(userUID: uid, groupID: groupID); await store.reload(pendingOnly: pendingOnly) }
        }
        .onChange(of: pendingOnly) { value in Task { await store.reload(pendingOnly: value) } }
        .onChange(of: scenePhase) { phase in if phase == .active { Task { await store.refresh() } } }
        .onChange(of: session.currentUser?.userUID) { _ in store.reset() }
        .onChange(of: notificationVersions) { _ in
            // 群系统会话收到变更后回查申请，不把系统消息正文冒充审核结果。
            Task { await store.refresh() }
        }
        .navigationDestination(isPresented: Binding(get: { profileRoute != nil }, set: { if !$0 { profileRoute = nil } })) {
            if let route = profileRoute {
                ContactRecordDetailView(store: LoginSessionService.shared.contacts, businessStore: businessStore,
                    contactID: route.contactID, fileHost: connection.current?.getFileHost, sourceGroupID: route.sourceGroupID)
            }
        }
        .onDisappear { if profileRoute == nil { store.reset() } }
    }

    /// 仅群系统会话的新消息触发回查，普通聊天或本页已读回写不重刷申请。
    private var notificationVersions: [String] {
        conversations.conversations.filter { $0.kind == .systemMessage }.map {
            "\($0.id)|\($0.latestTime?.timeIntervalSince1970 ?? 0)|\($0.preview)"
        }.sorted()
    }

    /// 待审核行支持勾选与确认，已处理行显示服务器状态。
    private func applicationRow(_ record: GroupApplicationRecord) -> some View {
        HStack(alignment: .top, spacing: 12.zoom()) {
            if pendingOnly && record.status == 1 {
                Button { toggle(record.id) } label: { Image(systemName: store.selectedIDs.contains(record.id) ? "checkmark.circle.fill" : "circle").font(.title3).frame(minWidth: 44, minHeight: 44) }.disabled(store.isReviewing).accessibilityLabel(record.nickname + (store.selectedIDs.contains(record.id) ? "，已选" : "，未选")).accessibilityAddTraits(store.selectedIDs.contains(record.id) ? .isSelected : [])
            }
            Button { openProfile(record.inviterID, groupID: record.groupID) } label: {
                ContactRecordAvatar(contact: ContactRecord(id: record.inviterID, nickname: record.inviterNickname,
                    avatar: record.inviterAvatar), fileHost: connection.current?.getFileHost, size: 48.zoom())
            }.buttonStyle(.plain).disabled(record.inviterID.isEmpty).accessibilityLabel("查看邀请人资料")
            VStack(alignment: .leading, spacing: 8.zoom()) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4.zoom()) { invitationContent(record) }
                    VStack(alignment: .leading, spacing: 4.zoom()) { invitationContent(record) }
                }
                if let roleName = businessStore.roleName(roleID: record.roleID, isDeleted: false) {
                    Text(roleName).font(.caption).foregroundStyle(MessagingTheme.accent)
                }
                Text("申请加入\(groupName(record.groupID))").font(.caption).foregroundStyle(MessagingTheme.secondaryText)
                if !record.reason.isEmpty { Text(record.reason).font(.subheadline).foregroundStyle(MessagingTheme.secondaryText) }
                if record.status == 1 {
                    if pendingOnly { Text("待审核").font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
                    else {
                        HStack(spacing: 12.zoom()) {
                            Button("同意") { store.selectedIDs = [record.id]; confirmation = true }.buttonStyle(.borderedProminent).tint(MessagingTheme.primaryAction).foregroundStyle(MessagingTheme.onPrimaryAction)
                            Button("拒绝", role: .destructive) { store.selectedIDs = [record.id]; confirmation = false }.buttonStyle(.bordered).tint(MessagingTheme.error)
                        }.controlSize(.large).frame(minHeight: 44).disabled(store.isReviewing)
                    }
                } else { Text(record.statusText).font(.caption).foregroundStyle(MessagingTheme.secondaryText) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 12.zoom()).accessibilityIdentifier("groupApplication.\(record.id)")
    }

    /// 两方名称分别使用真实UID，缺少身份只显示文字，不生成资料目标。
    @ViewBuilder private func invitationContent(_ record: GroupApplicationRecord) -> some View {
        Button(record.inviterNickname.isEmpty ? "邀请人" : record.inviterNickname) { openProfile(record.inviterID, groupID: record.groupID) }
            .buttonStyle(.plain).foregroundStyle(MessagingTheme.text).disabled(record.inviterID.isEmpty).frame(minHeight: 44)
        Text("邀请").foregroundStyle(MessagingTheme.secondaryText)
        Button(record.nickname.isEmpty ? "用户" : record.nickname) { openProfile(record.inviteeID, groupID: record.groupID) }
            .buttonStyle(.plain).foregroundStyle(MessagingTheme.accent).disabled(record.inviteeID.isEmpty).frame(minHeight: 44)
        Text("进群").foregroundStyle(MessagingTheme.secondaryText)
    }

    /// 从当前真实群快照取名称，群不在缓存时保留服务端群ID作为回退。
    private func groupName(_ id: String) -> String { groups.groups.first { $0.id == id && !$0.name.isEmpty }?.name ?? id }

    /// 资料携带原始来源群，仍由资料页核对群访问、私聊及用户限制。
    private func openProfile(_ id: String, groupID: String) {
        guard !id.isEmpty, !store.isReviewing else { return }
        profileRoute = ContactsRoute(contactID: id, sourceGroupID: groupID)
    }

    /// 全选按钮可反选，批量审核仅提交当前页真实待审核ID。
    private var selectAllButton: some View {
        Button { if allSelected { store.selectedIDs = [] } else { store.selectAll() } } label: { Label(allSelected ? "取消全选" : "全选", systemImage: allSelected ? "checkmark.circle.fill" : "circle").fixedSize(horizontal: true, vertical: false).frame(minHeight: 44) }
    }

    private var reviewButtons: some View {
        Group {
            Button("拒绝", role: .destructive) { confirmation = false }.buttonStyle(.bordered).tint(MessagingTheme.error)
            Button("同意(\(store.selectedIDs.count))") { confirmation = true }.buttonStyle(.borderedProminent).tint(MessagingTheme.primaryAction).foregroundStyle(MessagingTheme.onPrimaryAction)
        }.controlSize(.large).frame(minHeight: 44).disabled(store.selectedIDs.isEmpty || store.isReviewing)
    }

    /// 单行选择与底部批量操作使用同一个服务端ID集合。
    private func toggle(_ id: String) { if store.selectedIDs.contains(id) { store.selectedIDs.remove(id) } else { store.selectedIDs.insert(id) } }
}

private enum GroupApplicationFilter: String, CaseIterable { case all = "全部", pending = "待审核" }
