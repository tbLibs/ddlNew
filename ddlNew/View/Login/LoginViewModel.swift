//
//  LoginViewModel.swift
//  ddlNew
//
//  Created by taobo on 2026/9/21.
//

import Foundation
import Combine

/// 登录请求和入口操作，不依赖旧版会员状态；本步骤不保存会话或跳转主页。
@MainActor
final class LoginViewModel: ObservableObject {
    @Published private(set) var loginPhase: AccountLoginPhase = .idle
    /// 仅临时持有 ObjectMapper 解析结果，供下一阶段的会话处理使用。
    @Published private(set) var loginResponse: AccountLoginResponse?

    private let loginService: any AccountLoginServicing
    private var loginTask: Task<Void, Never>?
    /// 更换俱乐部、退出页面或新一轮点击后，旧回调不得发布结果。
    private var loginRunID = UUID()

    convenience init() {
        self.init(loginService: AccountLoginService.shared)
    }

    init(loginService: any AccountLoginServicing) {
        self.loginService = loginService
    }

    func login(account: String, password: String) {
        guard !loginPhase.isBusy else { return }
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
                self.loginResponse = response
                self.loginPhase = .succeeded
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
        loginRunID = UUID()
        loginTask?.cancel()
        loginTask = nil
        loginResponse = nil
        loginPhase = .idle
    }

    /// 退出当前俱乐部入口，重新选择邀请码；最新导航及配置缓存仍保留。
    func changeClub() {
        cancelLogin()
        do {
            try OSSNavigationStore.shared.clearLastUsableEntry()
        } catch {
            // 清空入口失败时停留在登录页，避免重启后仍恢复旧入口却误认为已完成切换。
            debugPrint("[更换俱乐部] 清空导航入口失败：\(error)")
            return
        }
        IMConnectionCoordinator.shared.reset()
        OSSConnectionBootstrap.shared.clearCurrent()
        RouterTool.shared.showAppPage = .invitationCode
    }
}
