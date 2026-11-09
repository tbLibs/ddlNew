import SwiftUI

/// 挂在真实Tab导航环境中，冷启动等该环境出现后再消费通知。
struct PushNavigationHandler: ViewModifier {
    let tab: MemberTab
    @EnvironmentObject private var navigation: ActivityNavigation
    @EnvironmentObject private var club: ClubStore
    @Environment(\.scenePhase) private var phase
    @ObservedObject private var push = PushCoordinator.shared
    @ObservedObject private var security = LoginSecurityCoordinator.shared
    func body(content: Content) -> some View {
        content
            .onAppear { handle() }
            .onReceive(push.$pendingNavigation) { _ in Task { @MainActor in handle() } }
            .onChange(of: club.selectedTab) { _ in handle() }
            .onChange(of: phase) { _ in handle() }
            .onChange(of: security.request?.id) { _ in handle() }
    }
    private func handle() {
        guard phase == .active, security.request == nil,
              RouterTool.shared.showAppPage == .tabbar,
              let owner = push.identity, let request = push.pendingNavigation,
              IMUserAuthenticationService.shared.isAuthenticated else { return }
        guard request.matches(owner) else { push.consumeNavigation(request.id); return }
        let destination = request.payload.destination
        let target: MemberTab = destination == .friends ? .contacts:.messages
        if club.selectedTab != target { club.selectedTab = target; return }
        guard tab == target else { return }
        if push.visibleConversation == destination { push.consumeNavigation(request.id); return }
        // 未绑定身份/未验证资源只进入列表，不把远程参数当作访问资格。
        navigation.path = NavigationPath()
        if request.hasOwner {
            if destination == .friends { navigation.open(ContactsPageRoute.newFriends) }
            else if let route = SDKPushClient.route(for:destination,owner:owner) { navigation.open(route) }
        }
        push.consumeNavigation(request.id)
    }
}
