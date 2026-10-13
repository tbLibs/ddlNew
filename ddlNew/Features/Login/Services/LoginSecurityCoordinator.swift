//
//  LoginSecurityCoordinator.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import Combine

/// AUTH 后检查安全策略；只有服务端明确要求才阻止进入业务页面。
@MainActor
final class LoginSecurityCoordinator: ObservableObject {
    static let shared = LoginSecurityCoordinator(service: .shared, requirementStore: PasswordSecurityRequirementStore.shared, isSessionCurrent: { uid, club in
        UserSessionStore.shared.currentUser?.userUID == uid
            && OSSNavigationStore.shared.lastUsableLiceseId() == club
            && IMUserAuthenticationService.shared.state == .ready
    }, signOut: { try await AppSessionRouter.signOut(changeClub: false) })

    @Published private(set) var request: PasswordSecurityRequest?
    @Published private(set) var isBusy = false
    @Published private(set) var oldPasswordVerified = false
    @Published private(set) var passwordChanged = false
    @Published private(set) var message: String?
    @Published private(set) var inputResetID = UUID()

    private struct Identity: Equatable { let uid: String; let club: String }
    private let service: PasswordSecurityService
    private let requirementStore: any PasswordSecurityRequirementStoring
    private let isSessionCurrent: @MainActor (String, String) -> Bool
    private let signOut: @MainActor () async throws -> Void
    private var identity: Identity?
    private var generation = UUID()
    private var foreground = true
    private var authenticated = true
    private var checked = false
    private var pendingCheck = false
    private var isChangingPassword = false
    private var pendingPasswordChange = false
    private var task: Task<Void, Never>?
    private var secret: PasswordSecuritySecret?
    /// 退出不属于检查任务，stop 不能取消正在执行的本地会话清理。
    private var signOutTask: Task<Void, Never>?

    init(service: PasswordSecurityService,
         requirementStore: any PasswordSecurityRequirementStoring,
         isSessionCurrent: @escaping @MainActor (String, String) -> Bool,
         signOut: @escaping @MainActor () async throws -> Void) {
        self.service = service
        self.requirementStore = requirementStore
        self.isSessionCurrent = isSessionCurrent
        self.signOut = signOut
    }

    func start(userUID: String, lastLiceseId: String) {
        let next = Identity(uid: userUID, club: lastLiceseId)
        guard !userUID.isEmpty, !lastLiceseId.isEmpty else { stop(); return }
        if identity != next {
            stop()
            identity = next
            checked = false
            pendingCheck = true
            if requirementStore.load()?.matches(userUID: userUID, lastLiceseId: lastLiceseId) == true {
                // 已确认强制要求先恢复屏障，检查超时或启动取消都不能放行缓存会话。
                request = PasswordSecurityRequest(id: UUID(), isForced: true, message: "该账号需要修改密码，请完成修改或退出登录")
            }
        }
        refreshIfNeeded()
    }

    /// 手动 AUTH 成功后补充单次密码检查；覆盖先启动的无密码检查，不能漏掉非强制提醒。
    func prepareManualLoginPassword(_ password: String, userUID: String, lastLiceseId: String) {
        start(userUID: userUID, lastLiceseId: lastLiceseId)
        guard let identity, foreground, authenticated, isCurrent(identity), !password.isEmpty else { return }
        cancelWork()
        let value = PasswordSecuritySecret(password)
        secret = value
        beginCheck(password: value)
    }

    func refreshIfNeeded() {
        guard pendingCheck || !checked else { return }
        refresh()
    }

    func refresh() {
        guard task == nil, signOutTask == nil, (request == nil || (request?.isForced == true && !checked)), let identity,
              foreground, authenticated, isCurrent(identity) else { return }
        beginCheck(password: nil)
    }

    func setForegroundActive(_ active: Bool) {
        guard foreground != active else { return }
        foreground = active
        if active { applyPendingPasswordChange(); refreshIfNeeded() }
        else { suspendWork() }
    }

    func setAuthenticated(_ ready: Bool) {
        guard authenticated != ready else { return }
        authenticated = ready
        if ready { applyPendingPasswordChange(); refreshIfNeeded() }
        else { suspendWork() }
    }

    func dismiss() {
        guard request?.isForced == false, !passwordChanged, !isBusy else { return }
        cancelWork()
        request = nil
        message = nil
        oldPasswordVerified = false
        inputResetID = UUID()
    }

    func verifyOldPassword(_ password: String) {
        guard !isBusy, !passwordChanged, let identity, let request,
              foreground, authenticated, isCurrent(identity) else { return }
        let value = PasswordSecuritySecret(password)
        secret = value
        isBusy = true
        message = nil
        let run = generation
        task = Task { [weak self] in
            guard let self else { value.discard(); return }
            defer { value.discard(); self.finish(run) }
            do {
                try await self.service.verifyOldPassword(userUID: identity.uid, password: value, valid: { self.valid(identity, run) })
                guard self.valid(identity, run), self.request?.id == request.id else { return }
                self.oldPasswordVerified = true
                self.inputResetID = UUID()
            } catch { self.publish(error, identity: identity, run: run) }
        }
    }

    func changePassword(_ password: String, confirmation: String, requiresSymbol: Bool) {
        guard !isBusy, oldPasswordVerified, !passwordChanged, let identity, let request,
              foreground, authenticated, isCurrent(identity) else { return }
        do { try PasswordChangeInput.validate(password: password, confirmation: confirmation, requiresSymbol: requiresSymbol) }
        catch { message = error.localizedDescription; return }
        let value = PasswordSecuritySecret(password)
        secret = value
        isBusy = true
        message = nil
        let run = generation
        isChangingPassword = true
        task = Task { [weak self] in
            guard let self else { value.discard(); return }
            defer { value.discard(); self.finish(run) }
            do {
                try await self.service.changePassword(userUID: identity.uid, password: value, valid: { self.valid(identity, run) }, onResetSucceeded: {
                    // 按身份和安全页面轮次保存提交结果，退出或切账号后的旧成功不能改变新会话。
                    guard self.identity == identity, self.request?.id == request.id else { return }
                    self.requirementStore.clear(userUID: identity.uid, lastLiceseId: identity.club)
                    self.pendingPasswordChange = true
                    self.applyPendingPasswordChange()
                })
            } catch { self.publish(error, identity: identity, run: run) }
        }
    }

    func exitToLogin() {
        guard signOutTask == nil, let identity else { return }
        let changed = passwordChanged
        isBusy = true
        signOutTask = Task { [weak self] in
            guard let self else { return }
            do {
                if changed {
                    // 已记住的旧密码不能继续回填；失败时仍继续退出有效会话。
                    try? RememberedLoginStore.shared.clear()
                }
                try await self.signOut()
                if changed, self.identity == nil || self.identity == identity {
                    LoginSecurityNoticeStore.shared.record(message: "密码已修改，请使用新密码重新登录")
                }
            } catch {
                if self.identity == identity {
                    self.message = changed ? "密码已修改，但退出未完成，请重试退出并重新登录" : "退出登录未完成，请重试"
                }
            }
            self.signOutTask = nil
            if self.identity == nil || self.identity == identity { self.isBusy = false }
        }
    }

    func stop(clearCachedRequirement: Bool = false) {
        if clearCachedRequirement { requirementStore.clear(userUID: identity?.uid, lastLiceseId: identity?.club) }
        cancelWork()
        identity = nil
        request = nil
        checked = false
        pendingCheck = false
        message = nil
        oldPasswordVerified = false
        passwordChanged = false
        pendingPasswordChange = false
        isChangingPassword = false
        inputResetID = UUID()
    }

    private func beginCheck(password: PasswordSecuritySecret?) {
        guard let identity else { password?.discard(); return }
        let hasPassword = password != nil
        if request != nil { isBusy = true }
        let run = generation
        pendingCheck = false
        task = Task { [weak self] in
            guard let self else { password?.discard(); return }
            defer { password?.discard(); self.finish(run) }
            do {
                let status = try await self.service.check(userUID: identity.uid, password: password, valid: { self.valid(identity, run) })
                guard self.valid(identity, run) else { return }
                self.checked = true
                // 同一会话内强制要求只能在成功改密或退出后解除；补充检查不能降级或替换强制页面。
                guard self.request?.isForced != true else { return }
                if status.requiresChange(hasSubmittedPassword: hasPassword) {
                    if status.forcedPasswordReset { self.requirementStore.save(userUID: identity.uid, lastLiceseId: identity.club) }
                    self.request = PasswordSecurityRequest(id: UUID(), isForced: status.forcedPasswordReset, message: status.message)
                }
            } catch {
                guard self.valid(identity, run) else { return }
                // 检查超时、断线或暂时失败不清凭据；下一次前台或资料刷新重试。
                self.pendingCheck = true
            }
        }
    }

    private func isCurrent(_ identity: Identity) -> Bool { isSessionCurrent(identity.uid, identity.club) }
    private func valid(_ identity: Identity, _ run: UUID) -> Bool {
        generation == run && self.identity == identity && foreground && authenticated && isCurrent(identity)
    }
    private func finish(_ run: UUID) {
        guard generation == run else { return }
        task = nil
        secret = nil
        isChangingPassword = false
        if signOutTask == nil { isBusy = false }
    }
    private func publish(_ error: Error, identity: Identity, run: UUID) {
        guard valid(identity, run), !(error is CancellationError) else { return }
        message = error.localizedDescription
    }
    private func applyPendingPasswordChange() {
        guard foreground, pendingPasswordChange, identity != nil, request != nil else { return }
        pendingPasswordChange = false
        // 旧接口只返回 Bool；没有新 token，必须退出当前会话重新密码登录。
        passwordChanged = true
        oldPasswordVerified = false
        inputResetID = UUID()
        message = "密码已修改，请重新登录"
        exitToLogin()
    }

    private func suspendWork() {
        if isChangingPassword {
            // SDK 没有取消请求句柄；保留已提交修改的等待，明文与原密码验证立即作废。
            secret?.discard()
            secret = nil
            oldPasswordVerified = false
            inputResetID = UUID()
            return
        }
        let wasChecking = task != nil && request == nil
        cancelWork()
        if wasChecking || !checked { pendingCheck = true }
        // 连接或前台轮次变化后必须重新验证原密码，不能沿用先前验证状态。
        oldPasswordVerified = false
        inputResetID = UUID()
    }
    private func cancelWork() {
        generation = UUID()
        task?.cancel()
        task = nil
        secret?.discard()
        secret = nil
        if signOutTask == nil { isBusy = false }
    }
}
