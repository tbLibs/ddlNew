//
//  LoginViewModel.swift
//  ddlNew
//
//  Created by taobo on 2026/9/21.
//

import Foundation
import Combine

/// 只协调请求、会话和页面状态；用户存储、SDK 认证及数据库各有独立入口。
@MainActor
final class LoginViewModel: ObservableObject {
    @Published private(set) var loginPhase: AccountLoginPhase = .idle
    /// 页面只保留用户资料，不长期持有 token 或设备凭据。
    @Published private(set) var userInfo: UserInfo?

    private let loginService: any AccountLoginServicing
    private let sessionService: any LoginSessionServicing
    /// 会话与 AUTH 全部完成后才交给 App 层跳转，便于测试登录和导航的先后顺序。
    private let onLoginSucceeded: @MainActor () -> Void
    private var authenticationSubscription: AnyCancellable?
    private var loginTask: Task<Void, Never>?
    /// 更换俱乐部、退出页面或新一轮点击后，旧回调不得发布结果。
    private var loginRunID = UUID()

    convenience init() {
        self.init(loginService: AccountLoginService.shared, sessionService: LoginSessionService.shared,
                  authenticationStates: IMUserAuthenticationService.shared.$state.eraseToAnyPublisher())
        // 页面重新创建时只恢复本进程已经建立的会话，不拿磁盘缓存冒充认证成功。
        let state = IMUserAuthenticationService.shared.state
        if state == .ready || state == .reconnecting, let user = UserSessionStore.shared.currentUser {
            userInfo = user
            loginPhase = .succeeded
        }
    }

    init(loginService: any AccountLoginServicing, sessionService: any LoginSessionServicing,
         authenticationStates: AnyPublisher<IMUserAuthenticationState, Never>? = nil,
         onLoginSucceeded: @escaping @MainActor () -> Void = { AppSessionRouter.enterMain() }) {
        self.loginService = loginService
        self.sessionService = sessionService
        self.onLoginSucceeded = onLoginSucceeded
        authenticationSubscription = authenticationStates?.sink { [weak self] state in
            guard let self, self.loginPhase == .succeeded else { return }
            if case .failed(let message) = state {
                self.userInfo = nil
                self.loginPhase = .failed(message)
            }
        }
    }

    func login(account: String, password: String) {
        guard !loginPhase.isBusy, loginPhase != .succeeded else { return }
        cancelLogin()
        let runID = loginRunID
        loginPhase = .fetchingKey
        loginTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.loginRunID == runID { self.loginTask = nil }
            }
            do {
                let response = try await self.loginService.login(account: account, password: password) { [weak self] phase in
                    guard let self, self.loginRunID == runID, !Task.isCancelled else { return }
                    self.loginPhase = phase
                }
                try Task<Never, Never>.checkCancellation()
                guard self.loginRunID == runID else { return }
                try await self.sessionService.completeLogin(response, account: account) { [weak self] phase in
                    guard let self, self.loginRunID == runID, !Task.isCancelled else { return }
                    self.loginPhase = phase
                }
                try Task<Never, Never>.checkCancellation()
                guard self.loginRunID == runID else { return }
                self.userInfo = response.userInfo
                // 跳转会触发 LoginView.onDisappear；先结束任务，不能让页面退出取消已认证会话。
                self.loginTask = nil
                self.loginPhase = .succeeded
                self.onLoginSucceeded()
            } catch is CancellationError {
                if self.loginRunID == runID { self.loginPhase = .idle }
            } catch {
                guard self.loginRunID == runID, !Task.isCancelled else { return }
                self.loginPhase = .failed(error.localizedDescription)
                // 页面显示业务提示，新增日志不重复输出请求凭据；SDK 原有完整日志仍保留。
                if case AccountLoginError.businessFailure(let code, _) = error {
                    debugPrint("[账号登录] 请求失败，业务码：\(code)")
                } else {
                    debugPrint("[账号登录] 请求未完成，请查看页面提示")
                }
            }
        }
    }

    /// SDK 请求可能已发出；取消只丢弃本轮结果，不宣称撤销服务端登录操作。
    func cancelLogin() {
        // 离开页面只取消未完成的登录，不注销已经通过 AUTH 的会话。
        guard loginTask != nil || loginPhase != .succeeded else { return }
        loginRunID = UUID()
        loginTask?.cancel()
        loginTask = nil
        sessionService.cancelPendingLogin()
        userInfo = nil
        loginPhase = .idle
    }

    /// 退出当前俱乐部入口，重新选择邀请码；最新导航及配置缓存仍保留。
    func changeClub() {
        cancelLogin()
        do {
            try sessionService.clearSession()
            try OSSNavigationStore.shared.clearLastUsableEntry()
        } catch {
            // 清空入口失败时停留在登录页，避免重启后仍恢复旧入口却误认为已完成切换。
            debugPrint("[更换俱乐部] 清空导航入口失败：\(error)")
            userInfo = nil
            loginPhase = .failed("清理俱乐部会话失败，请重试")
            IMConnectionCoordinator.shared.startCachedReconnect()
            return
        }
        userInfo = nil
        loginPhase = .idle
        IMConnectionCoordinator.shared.reset()
        OSSConnectionBootstrap.shared.clearCurrent()
        RouterTool.shared.showAppPage = .invitationCode
    }
}
