//
//  ddlNewApp.swift
//  ddlNew
//
//  Created by taobo on 2026/9/18.
//

import SwiftUI
import Sentry


@main
struct ddlNewApp: App {
    
    /// 负责启动时配置 Sentry。
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    /// 根页面根据共享路由状态在邀请码、登录和主界面之间切换。
    @StateObject var router = RouterTool.shared
    @StateObject private var language = AppLanguageStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var loginSecurity = LoginSecurityCoordinator.shared

    /// 供活动与俱乐部页面展示；真实登录资格由用户会话与 AUTH 控制。
    @StateObject private var clubStore = ClubStore()
    /// 根页面持续监听账号失效，即使登录页已经销毁也能退出主界面。
    @ObservedObject private var authentication = IMUserAuthenticationService.shared

    /// 本地恢复只执行一次，避免页面重建时覆盖用户当前路由。
    @State private var hasRestoredLocalEntry = false
    /// 连接对象只用于取消尚未完成的根任务；启动页不发起网络连接。
    @ObservedObject private var connection = IMConnectionCoordinator.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasRestoredLocalEntry {
                    switch router.showAppPage {
                    case .invitationCode:
                        InvitationCodeView()
                    case .login:
                        LoginView()
                    case .tabbar:
                        TabbarView()
                            .id(UserSessionStore.shared.currentUser?.userUID)
                            .accessibilityIdentifier("mainTabs")
                    }
                } else {
                    // 只等待本地入口校验，不等待 TCP 或 AUTH。
                    Color(uiColor: .systemBackground)
                        .ignoresSafeArea()
                        .overlay(alignment: .bottom) {
                            VStack(spacing: 10) {
                                ProgressView()
                                Text(L10n.tr("正在恢复本地入口…"))
                                    .font(.footnote)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 40)
                            .accessibilityIdentifier("startupConnectionStatus")
                        }
                }
            }
            .environmentObject(clubStore)
            .environment(\.locale, language.locale)
            .callPresentation()
            .fullScreenCover(item: Binding(get: { loginSecurity.request }, set: { _ in loginSecurity.dismiss() })) { request in
                PasswordChangeView(request: request, coordinator: loginSecurity)
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active { language.refreshSystemLanguage() }
                MessageConnectionMonitor.shared.setForeground(phase == .active)
                PushCoordinator.shared.setForeground(phase == .active)
                loginSecurity.setForegroundActive(phase == .active)
                SessionMaintenanceCoordinator.shared.setForegroundActive(phase == .active)
                CallCoordinator.shared.setForeground(phase == .active)
            }
            .task {
                guard !hasRestoredLocalEntry else { return }
                MessageConnectionMonitor.shared.setForeground(scenePhase == .active)
                PushCoordinator.shared.setForeground(scenePhase == .active)
                loginSecurity.setForegroundActive(scenePhase == .active)
                SessionMaintenanceCoordinator.shared.setForegroundActive(scenePhase == .active)
                CallCoordinator.shared.setForeground(scenePhase == .active)
                do {
                    let page = try await AppStartupCoordinator.restoreLocalEntry()
                    try Task<Never, Never>.checkCancellation()
                    router.showAppPage = page
                    hasRestoredLocalEntry = true
                    LoginSessionService.shared.finishStartupRestoration()
                } catch is CancellationError {
                    LoginSessionService.shared.cancelStartupRestoration()
                    connection.reset()
                } catch {
                    debugPrint("[启动恢复] 初始化失败：\(error)")
                }
            }
            .onReceive(authentication.$state) { state in
                loginSecurity.setAuthenticated(state == .ready)
                SessionMaintenanceCoordinator.shared.setAuthenticated(state == .ready)
                AppSessionRouter.handleAuthenticationState(state)
            }
            .onReceive(clubStore.$stage) { stage in
                // 展示状态只转发用户主动退出的意图，不允许演示登录绕过真实 AUTH。
                switch stage {
                case .login:
                    Task {
                        do { try await AppSessionRouter.signOut(changeClub: false) }
                        catch { debugPrint("[退出登录] 清理会话失败：\(error)") }
                    }
                case .invite:
                    Task {
                        do { try await AppSessionRouter.signOut(changeClub: true) }
                        catch { debugPrint("[更换俱乐部] 清理会话失败：\(error)") }
                    }
                case .member, .splash, .restoreFailed:
                    break
                }
            }
        }
    }
}
