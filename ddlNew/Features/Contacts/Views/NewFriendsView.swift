//
//  NewFriendsView.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import SwiftUI

/// 好友申请支持接受、重新申请与本机隐藏，禁止编造拒绝接口。
struct NewFriendsView: View {
    @ObservedObject var businessStore: ContactsBusinessStore
    let fileHost: URL?
    @ObservedObject private var permissions = UserRoleAuthorityStore.shared
    @State private var hiding: FriendApplicationRecord?
    @State private var viewport = CGRect.zero
    @State private var visibleFrames: [String: CGRect] = [:]

    var body: some View {
        List {
            if businessStore.applications.isEmpty && !businessStore.isLoading && businessStore.errorMessage == nil {
                Text("暂无好友申请").foregroundStyle(.secondary)
            }
            ForEach(businessStore.applications) { application in
                if let userUID = businessStore.identity?.userUID {
                    HStack(spacing: 12) {
                        ContactRecordAvatar(contact: application.displayContact(for: userUID), fileHost: fileHost, size: 44)
                        NavigationLink(value: ContactsRoute(contactID: application.peerID(for: userUID), applicationID: application.id)) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(application.name(for: userUID).isEmpty ? application.peerID(for: userUID) : application.name(for: userUID)).font(.headline)
                                if let role = businessStore.roleName(roleID: application.roleID(for: userUID), isDeleted: application.action(for: userUID) == .unavailable) { Text(role).font(.caption).foregroundStyle(HomeTheme.forest) }
                                Text(application.source == 0 ? "通过二维码添加" : "通过搜索添加").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 6)
                        action(application, userUID: userUID)
                    }
                    .background(GeometryReader { proxy in Color.clear.preference(key: FriendApplicationFrames.self, value: [application.id: proxy.frame(in: .global)]) })
                    .swipeActions { Button("在本机隐藏", role: .destructive) { hiding = application } }
                }
            }
            if businessStore.hasMoreApplications { Button("加载更多") { Task { await businessStore.loadMoreApplications() } }.disabled(businessStore.isLoading) }
            if businessStore.isLoading { ProgressView("正在读取申请") }
            if let error = businessStore.errorMessage { Text(error).foregroundStyle(ClubTheme.error) }
            if let notice = businessStore.notice { Text(notice).foregroundStyle(.secondary) }
        }
        .background(GeometryReader { proxy in Color.clear.preference(key: FriendApplicationViewport.self, value: proxy.frame(in: .global)) })
        .onPreferenceChange(FriendApplicationViewport.self) { viewport = $0; markVisibleRows() }
        .onPreferenceChange(FriendApplicationFrames.self) { visibleFrames = $0; markVisibleRows() }
        .onChange(of: businessStore.applications) { _ in markVisibleRows() }
        .tint(HomeTheme.forest)
        .navigationTitle("新朋友").navigationBarTitleDisplayMode(.inline).navigationBarHidden(false)
        .task { await businessStore.reload() }
        .refreshable { await businessStore.reload() }
        .confirmationDialog("在本机隐藏这条申请？", isPresented: Binding(get: { hiding != nil }, set: { if !$0 { hiding = nil } }), titleVisibility: .visible) {
            Button("在本机隐藏", role: .destructive) { if let hiding { businessStore.hide(hiding) }; hiding = nil }
            Button("取消", role: .cancel) { hiding = nil }
        } message: { Text("只影响当前账号在本机的显示，不会拒绝申请，也不会通知对方。") }
    }

    /// 只读取与当前列表可见区域有交集的行，未呈现的分页不标已读。
    private func markVisibleRows() {
        guard !viewport.isEmpty else { return }
        for application in businessStore.applications {
            if let frame = visibleFrames[application.id], frame.intersects(viewport), !frame.isEmpty { businessStore.markVisible(application) }
        }
    }

    /// 申请按钮按真实方向和状态显示，注销和未知状态禁操作。
    @ViewBuilder private func action(_ application: FriendApplicationRecord, userUID: String) -> some View {
        switch application.action(for: userUID) {
        case .accept:
            Button("接受") { Task { await businessStore.perform(.accept(friendID: application.peerID(for: userUID))) } }.buttonStyle(.bordered).disabled(businessStore.isSubmitting || permissions.current?.allows("allowAddFriend") != true)
        case .reapply:
            Button("重新申请") { Task { await businessStore.perform(.apply(friendID: application.peerID(for: userUID))) } }.buttonStyle(.bordered).disabled(businessStore.isSubmitting || permissions.current?.allows("allowAddFriend") != true)
        case .waiting: Text("等待验证").font(.caption).foregroundStyle(.secondary)
        case .accepted: Text("已添加").font(.caption).foregroundStyle(.secondary)
        case .expired: Text("已过期").font(.caption).foregroundStyle(.secondary)
        case .unavailable: Text("不可操作").font(.caption).foregroundStyle(.secondary)
        }
    }
}
