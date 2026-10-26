//
//  TabbarView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 主界面唯一的四栏容器，每个 Tab 保留独立的导航栈。
struct TabbarView: View {
    @EnvironmentObject private var store: ClubStore
    /// 角标随真实 SDK 会话快照变化；ClubCommunity 仍供其他演示页面使用。
    @ObservedObject private var conversations = LoginSessionService.shared.conversations
    @ObservedObject private var contacts = LoginSessionService.shared.contacts
    @ObservedObject private var contactBusiness = LoginSessionService.shared.contactBusiness
    @ObservedObject private var groups = LoginSessionService.shared.groups
    @ObservedObject private var userSession = UserSessionStore.shared
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    @StateObject private var community = ClubCommunity()

    var body: some View {
        TabView(selection: $store.selectedTab) {
            tab(.home) {
                ClubHomeView(userName: userSession.currentUser?.nickname ?? "")
            }
            tab(.messages) { MessageView(store: conversations) }
            tab(.contacts) {
                ContactsView(store: contacts, businessStore: contactBusiness, groupsStore: groups,
                             fileHost: connection.current?.getFileHost)
            }
            tab(.profile) { MineView() }
        }
        .tint(HomeTheme.forest)
        .environmentObject(community)
        .onChange(of: contacts.contacts) { _ in
            // 好友同步可能晚于会话同步；头像、备注和在线状态变化后重读同一好友库快照。
            Task { await conversations.reload() }
        }
    }

    /// 四栏首页统一使用系统导航工具栏，各自原导航栈和稳定ID路由保持不变。
    private func tab<Content: View>(_ tab: MemberTab, @ViewBuilder content: () -> Content) -> some View {
        ActivityNavigationScope {
            content()
                .toolbar(.visible, for: .navigationBar)
                .navigationDestination(for: ChatRoute.self) { route in ChatRoomView(route: route) }
                .navigationDestination(for: ContactsRoute.self) { route in
                    ContactRecordDetailView(store: contacts, businessStore: contactBusiness,
                        contactID: route.contactID, fileHost: connection.current?.getFileHost,
                        sourceGroupID: route.sourceGroupID, applicationID: route.applicationID)
                }
                .navigationDestination(for: ContactsPageRoute.self) { route in
                    ContactsPageDestination(route: route, businessStore: contactBusiness,
                        fileHost: connection.current?.getFileHost)
                }
                .navigationDestination(for: MassMessageRoute.self) { route in MassMessageView(route: route) }
                .navigationDestination(for: SafetyRoute.self) { _ in BlacklistView(businessStore: contactBusiness) }
        }
        .tabItem {
            Label(tab.rawValue, systemImage: tab.icon)
        }
        .badge(tab == .messages ? conversations.totalUnreadCount : (tab == .contacts ? contactBusiness.unreadCount : 0))
        .tag(tab)
    }
}
