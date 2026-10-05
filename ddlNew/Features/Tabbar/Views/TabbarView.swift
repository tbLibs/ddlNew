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
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    @StateObject private var community = ClubCommunity()

    var body: some View {
        TabView(selection: $store.selectedTab) {
            tab(.home) {
                ClubHomeView(userName: UserSessionStore.shared.currentUser?.nickname ?? "")
            }
            tab(.messages) { MessageView(store: conversations) }
            tab(.contacts) {
                ContactsView(store: contacts,
                             fileHost: connection.current?.getFileHost)
            }
            tab(.profile) { MineView() }
        }
        .tint(HomeTheme.forest)
        .environmentObject(community)
        .onChange(of: contacts.contacts) { _ in
            // 好友同步可能晚于会话同步；头像以最新好友库为准，变化后重读会话快照。
            Task { await conversations.reload() }
        }
    }

    private func tab<Content: View>(_ tab: MemberTab, @ViewBuilder content: () -> Content) -> some View {
        ActivityNavigationScope {
            content()
                .navigationBarHidden(true)
        }
        .tabItem {
            Label(tab.rawValue, systemImage: tab.icon)
        }
        .badge(tab == .messages ? conversations.totalUnreadCount : 0)
        .tag(tab)
    }
}
