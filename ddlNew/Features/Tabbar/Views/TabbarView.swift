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
    @StateObject private var community = ClubCommunity()

    var body: some View {
        TabView(selection: $store.selectedTab) {
            tab(.home) {
                ClubHomeView(userName: UserSessionStore.shared.currentUser?.nickname ?? "")
            }
            tab(.messages) { MessageView() }
            tab(.contacts) {
                ContactsView(store: LoginSessionService.shared.contacts,
                             fileHost: OSSConnectionBootstrap.shared.current?.getFileHost)
            }
            tab(.profile) { MineView() }
        }
        .tint(HomeTheme.forest)
        .environmentObject(community)
    }

    private func tab<Content: View>(_ tab: MemberTab, @ViewBuilder content: () -> Content) -> some View {
        ActivityNavigationScope {
            content()
                .navigationBarHidden(true)
        }
        .tabItem {
            Label(tab.rawValue, systemImage: tab.icon)
        }
        .badge(tab == .messages ? community.unreadCount : 0)
        .tag(tab)
    }
}
