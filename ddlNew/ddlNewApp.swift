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

    /// OldVersion 登录与会员页面共用的状态。
    @StateObject private var oldVersionStore = ClubStore()

    /// 本地恢复只执行一次，避免页面重建时覆盖用户当前路由。
    @State private var hasRestoredLocalEntry = false
    /// 缓存恢复期间在启动等待页展示连接进度，不提前创建登录页面。
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
                        // LoginScreen() // OldVersion 原登录页保留，当前 UI 已接入 LoginView。
                    case .tabbar:
                        // TabbarView() // 新版主页面保留，后续版本恢复使用。
                        MemberTabs()
                    }
                } else {
                    // 复用系统启动页外观，缓存连接和最新配置都就绪后才退出。
                    LaunchWaitingView()
                        .ignoresSafeArea()
                        .overlay(alignment: .bottom) {
                            VStack(spacing: 10) {
                                ProgressView()
                                Text(connection.phase == .idle ? "正在恢复本地入口…" : connection.phase.message)
                                    .font(.footnote)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 40)
                            .accessibilityIdentifier("startupConnectionStatus")
                        }
                }
            }
            .environmentObject(oldVersionStore)
            .task {
                guard !hasRestoredLocalEntry else { return }
                do {
                    let page = try await AppStartupCoordinator.restoreLocalEntry()
                    try Task<Never, Never>.checkCancellation()
                    router.showAppPage = page
                    hasRestoredLocalEntry = true
                } catch is CancellationError {
                    connection.reset()
                } catch {
                    debugPrint("[启动恢复] 初始化失败：\(error)")
                }
            }
            .onReceive(oldVersionStore.$stage) { stage in
                // OldVersion 的登录、退出和更换俱乐部结果同步到当前根路由。
                switch stage {
                case .member:
                    router.showAppPage = .tabbar
                case .login:
                    router.showAppPage = .login
                case .invite:
                    router.showAppPage = .invitationCode
                case .splash, .restoreFailed:
                    break
                }
            }
        }
    }
}
