//
//  TabbarView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 主界面唯一的四栏容器，每个 Tab 保留独立的导航栈。
struct TabbarView: View {
    @Environment(\.locale) private var localizationLocale
    @EnvironmentObject private var store: ClubStore
    /// 角标随真实 SDK 会话快照变化；ClubCommunity 仍供其他演示页面使用。
    @ObservedObject private var conversations = LoginSessionService.shared.conversations
    @ObservedObject private var contacts = LoginSessionService.shared.contacts
    @ObservedObject private var contactBusiness = LoginSessionService.shared.contactBusiness
    @ObservedObject private var groups = LoginSessionService.shared.groups
    @ObservedObject private var connection = OSSConnectionBootstrap.shared
    @ObservedObject private var session = LoginSessionService.shared
    @ObservedObject private var loginSecurity = LoginSecurityCoordinator.shared
    @ObservedObject private var personalTasks = PersonalTaskStore.shared
    @StateObject private var community = ClubCommunity()
    @State private var messagePullDown = MessagePullDownState()

    var body: some View {
        TabView(selection: $store.selectedTab) {
            tab(.messages) { MessageView(store: conversations, pullDown: messagePullDown) }
            tab(.contacts) {
                ContactsView(store: contacts, businessStore: contactBusiness, groupsStore: groups,
                             fileHost: connection.current?.getFileHost)
            }
            tab(.tasks) { PersonalTasksView().id(personalTasks.epoch) }
            tab(.profile) { MineView() }
        }
        .alert(L10n.tr("提示"), isPresented: Binding(
            get: { session.curfewMessage != nil && loginSecurity.request == nil },
            set: { if !$0 { session.dismissCurfew() } }
        )) {
            Button(L10n.tr("我知道了"), role: .cancel) { }
        } message: {
            Text(verbatim: session.curfewMessage ?? "")
        }
        .modifier(MiniAppPresentation(feature: MiniAppsFeature.shared))
        .modifier(MessagePullDownPresentation(state: messagePullDown))
        .onChange(of: store.selectedTab) { _ in messagePullDown.reset() }
        .onAppear { updatePushBadge() }
        .onReceive(conversations.$totalUnreadCount) { _ in Task { @MainActor in updatePushBadge() } }
        .onReceive(conversations.$hasLoadedSnapshot) { _ in Task { @MainActor in updatePushBadge() } }
        .onReceive(contactBusiness.$unreadCount) { _ in Task { @MainActor in updatePushBadge() } }
        .onReceive(contactBusiness.$hasUnreadSnapshot) { _ in Task { @MainActor in updatePushBadge() } }
        .tint(HomeTheme.forest)
        .environmentObject(community)
        .onChange(of: contacts.contacts) { _ in
            // 好友同步可能晚于会话同步；头像、备注和在线状态变化后重读同一好友库快照。
            Task { await conversations.reload() }
        }
    }

    private func updatePushBadge() {
        PushCoordinator.shared.updateBadge(
            messages: conversations.hasLoadedSnapshot ? conversations.totalUnreadCount : nil,
            friends: contactBusiness.hasUnreadSnapshot ? contactBusiness.unreadCount : nil)
    }

    /// 四个主页面使用独立导航栈，保留稳定ID路由与通知跳转。
    private func tab<Content: View>(_ tab: MemberTab, @ViewBuilder content: () -> Content) -> some View {
        ActivityNavigationScope {
            content()
                .modifier(PushNavigationHandler(tab: tab))
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
                .navigationDestination(for: MineSupportRoute.self) { route in
                    switch route {
                    case .network: NetworkDiagnosticScreen()
                    case .about: AboutUsScreen()
                    }
                }
                .navigationDestination(for: SafetyRoute.self) { _ in BlacklistView(businessStore: contactBusiness) }
        }
        .tabItem {
            Label(tab.displayName, systemImage: tab.icon)
        }
        .badge(tab == .messages ? conversations.totalUnreadCount : (tab == .contacts ? contactBusiness.unreadCount : 0))
        .tag(tab)
    }
}
