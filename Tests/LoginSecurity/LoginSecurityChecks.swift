//
//  LoginSecurityChecks.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

@MainActor final class IMUserAuthenticationService {
    static let shared = IMUserAuthenticationService()
    var state: State = .ready
    enum State { case ready, reconnecting }
}
@MainActor final class UserSessionStore {
    static let shared = UserSessionStore()
    var currentUser: User? = User(userUID: "u")
    struct User { var userUID: String }
}
@MainActor final class OSSNavigationStore {
    static let shared = OSSNavigationStore()
    func lastUsableLiceseId() -> String? { "club" }
}
@MainActor enum AppSessionRouter { static func signOut(changeClub: Bool) async throws {} }
@MainActor final class LoginSecurityNoticeStore {
    static let shared = LoginSecurityNoticeStore()
    func record(message: String) {}
}
@MainActor enum RememberedLoginStore { static let shared = Store(); class Store { func clear() throws {} } }
@MainActor final class SDKPasswordSecurityClient: PasswordSecurityDriving {
    func fetchEncryptKey() async throws -> String { "key" }
    func checkStrength(parameters: [String: Any]) async throws -> PasswordSecurityStatus { .init(isWeakPassword: false, type: "", forcedPasswordReset: false) }
    func checkOldPassword(parameters: [String: Any]) async throws -> Bool { true }
    func resetPassword(parameters: [String: Any]) async throws -> Bool { true }
}
enum LXChatEncrypt { static func method4(_ value: String) -> String? { "cipher" } }
@MainActor final class FakeDriver: PasswordSecurityDriving {
    var calls: [String] = []
    var parameters: [[String: Any]] = []
    var status = PasswordSecurityStatus(isWeakPassword: true, type: "WEAK_PASSWORD", forcedPasswordReset: true)
    var oldResult = true
    var resetResult = true
    var afterKey: () -> Void = {}
    var suspended: CheckedContinuation<PasswordSecurityStatus, Error>?
    var suspendReset = false
    var resetContinuation: CheckedContinuation<Bool, Error>?
    var suspendCheck = false
    var failure = false
    func fetchEncryptKey() async throws -> String {
        calls.append("key"); afterKey(); return "key-\(calls.count)"
    }
    func checkStrength(parameters: [String: Any]) async throws -> PasswordSecurityStatus {
        calls.append("strength"); self.parameters.append(parameters)
        if suspendCheck { return try await withCheckedThrowingContinuation { suspended = $0 } }
        if failure { throw AccountLoginError.timedOut }
        return status
    }
    func checkOldPassword(parameters: [String: Any]) async throws -> Bool {
        calls.append("old"); self.parameters.append(parameters); return oldResult
    }
    func resetPassword(parameters: [String: Any]) async throws -> Bool {
        calls.append("reset"); self.parameters.append(parameters)
        if suspendReset { return try await withCheckedThrowingContinuation { resetContinuation = $0 } }
        return resetResult
    }
}
let loginForcedPasswordRequirementAppStorageKey = "ddlNew.loginForcedPasswordRequirement.v1"
@MainActor final class MemoryRequirementStore: PasswordSecurityRequirementStoring {
    var requirement: PasswordSecurityRequirement?
    func load() -> PasswordSecurityRequirement? { requirement }
    func save(userUID: String, lastLiceseId: String) { requirement = .init(userUID: userUID, lastLiceseId: lastLiceseId) }
    func clear(userUID: String?, lastLiceseId: String?) {
        if let userUID, let lastLiceseId, requirement?.matches(userUID: userUID, lastLiceseId: lastLiceseId) == false { return }
        requirement = nil
    }
}
@MainActor final class Fixture {
    let driver = FakeDriver()
    let requirementStore = MemoryRequirementStore()
    var current = true
    var exits = 0
    var failExit = false
    var encrypted: [String] = []
    lazy var service = PasswordSecurityService(driver: driver, encrypt: { [unowned self] value in self.encrypted.append(value); return "cipher" })
    lazy var coordinator = LoginSecurityCoordinator(service: service, requirementStore: requirementStore, isSessionCurrent: { [unowned self] _, _ in self.current }, signOut: { [unowned self] in self.exits += 1; if self.failExit { throw AccountLoginError.timedOut } })
}
@main struct Checks {
    @MainActor static func main() async throws {
        var checks = 0
        func expect(_ value: Bool, _ reason: String) { precondition(value, reason); checks += 1 }
        for (code, word) in [(40015,"账号"),(40029,"设备"),(40030,"IP"),(40045,"5 分钟"),(40062,"24 小时")] {
            expect(AccountLoginError.businessFailure(code: code, message: "").localizedDescription.contains(word), "明确安全错误")
        }
        expect(AccountLoginError.businessFailure(code: 90018, message: "203.0.113.8").localizedDescription.contains("203.0.113.8"), "白名单显示真实IP")
        expect(!LoginSecurityNotice.sessionMessage(code: 999, message: "").contains("封禁"), "未知999不是封禁")
        expect(LoginSecurityNotice.sessionMessage(code: 11, message: "").contains("设备"), "设备下线type")
        expect(LoginSecurityNotice.sessionMessage(code: 2, message: "").contains("封禁"), "同步账号封禁type")
        expect(UserSessionError.authenticationRejected(code: 10, message: "").isAuthenticationRejected, "识别AUTH拒绝")
        expect(!UserSessionError.authenticationTimedOut.invalidatesCachedSession, "超时保留凭据")
        expect(AccountLoginError.businessFailure(code: 2036, message: "").localizedDescription.contains("账号或密码错误"), "保留2036")
        expect(AccountLoginError.businessFailure(code: 10009, message: "secret").localizedDescription.contains("安全码"), "保留安全码且不泄漏scKey")
        let parsed = try PasswordSecurityStatus(json: ["isWeakPassword":"1", "type":"PASSWORD_EQ_ACCOUNT", "roleConfigMap":["forced_password_reset":"true"]])
        expect(parsed.requiresChange(hasSubmittedPassword: false), "缓存恢复强制修改")
        let optional = PasswordSecurityStatus(isWeakPassword: true, type: "WEAK_PASSWORD", forcedPasswordReset: false)
        expect(!optional.requiresChange(hasSubmittedPassword: false), "缓存恢复非强制弱密码不弹窗")
        expect(optional.requiresChange(hasSubmittedPassword: true), "手动登录非强制弱密码提醒")
        do { _ = try PasswordSecurityStatus(json: ["isWeakPassword":"invalid"]); preconditionFailure("畸形响应不能当安全") } catch { checks += 1 }
        do { try PasswordChangeInput.validate(password: "abc123", confirmation: "abc123", requiresSymbol: true); preconditionFailure("要求英文符号") } catch { checks += 1 }
        try PasswordChangeInput.validate(password: "abc123!", confirmation: "abc123!", requiresSymbol: true)
        checks += 1
        let f = Fixture()
        let secret = PasswordSecuritySecret("fixture-password")
        _ = try await f.service.check(userUID: "u", password: secret, valid: { true })
        expect(secret.isEmpty, "加密后立即丢弃明文")
        expect(f.driver.parameters[0]["userUid"] as? String == "u", "旧检查UID字段")
        expect(f.driver.parameters[0]["password"] as? String == "cipher", "旧检查密码字段")
        expect(f.encrypted == ["key-1fixture-password"], "method4密钥在前")
        _ = try await f.service.check(userUID: "u", password: nil, valid: { true })
        expect(f.driver.parameters[1]["password"] == nil && f.driver.parameters[1]["encryptKey"] == nil, "缓存恢复不提交密码")
        let stale = Fixture()
        stale.driver.afterKey = { stale.current = false }
        do { _ = try await stale.service.check(userUID: "u", password: .init("fixture"), valid: { stale.current }); preconditionFailure("换账号后不能提交旧密码") } catch { checks += 1 }
        expect(stale.driver.calls == ["key"], "迟到密钥不提交业务")
        let old = Fixture()
        old.driver.oldResult = false
        do { try await old.service.verifyOldPassword(userUID: "u", password: .init("fixture"), valid: { true }); preconditionFailure("原密码错误") } catch { checks += 1 }
        expect(!old.driver.calls.contains("reset"), "原密码失败不改新密码")
        let reset = Fixture()
        reset.driver.resetResult = false
        do { try await reset.service.changePassword(userUID: "u", password: .init("fixture"), valid: { true }); preconditionFailure("reset false不能当成功") } catch { checks += 1 }
        let flow = Fixture()
        flow.coordinator.start(userUID: "u", lastLiceseId: "club")
        await settle()
        expect(flow.coordinator.request?.isForced == true, "明确强制后覆盖主界面")
        flow.coordinator.dismiss()
        expect(flow.coordinator.request != nil, "强制不能稍后或关闭")
        let forcedRequestID = flow.coordinator.request?.id
        flow.driver.status = optional
        flow.coordinator.prepareManualLoginPassword("fixture-password", userUID: "u", lastLiceseId: "club")
        await settle()
        expect(flow.coordinator.request?.isForced == true, "已有强制要求不能被手动补充检查降级")
        expect(flow.coordinator.request?.id == forcedRequestID, "补充检查不能替换既有强制页面轮次")
        flow.coordinator.dismiss()
        expect(flow.coordinator.request != nil, "补充非强制结果后仍不能关闭")
        flow.driver.suspendCheck = true
        flow.coordinator.prepareManualLoginPassword("fixture-password", userUID: "u", lastLiceseId: "club")
        await settle()
        flow.coordinator.setForegroundActive(false)
        expect(flow.coordinator.request?.isForced == true, "后台取消手动检查不能清除强制要求")
        flow.driver.suspended?.resume(returning: optional)
        await settle()
        flow.coordinator.setForegroundActive(true)
        await settle()
        expect(flow.coordinator.request?.isForced == true && flow.coordinator.request?.id == forcedRequestID, "迟到非强制回调不能解除或替换强制页面")
        flow.coordinator.stop()
        expect(flow.coordinator.request == nil, "退出清安全状态")
        let race = Fixture()
        race.driver.suspendCheck = true
        race.coordinator.start(userUID: "u", lastLiceseId: "club")
        await settle()
        race.coordinator.stop()
        race.driver.suspended?.resume(returning: race.driver.status)
        await settle()
        expect(race.coordinator.request == nil, "退出后迟到检查不能锁住新会话")
        let retry = Fixture()
        retry.driver.failure = true
        retry.coordinator.start(userUID: "u", lastLiceseId: "club")
        await settle()
        expect(retry.coordinator.request == nil, "临时失败不锁死或登出")
        retry.driver.failure = false
        retry.coordinator.refresh()
        await settle()
        expect(retry.coordinator.request?.isForced == true, "恢复后重试检查")
        retry.coordinator.setForegroundActive(false)
        expect(!retry.coordinator.isBusy && retry.coordinator.request != nil, "后台取消保留强制要求")
        let manual = Fixture()
        manual.driver.status = optional
        manual.coordinator.start(userUID: "u", lastLiceseId: "club")
        await settle()
        expect(manual.coordinator.request == nil, "缓存检查不显示非强制")
        manual.coordinator.prepareManualLoginPassword("fixture", userUID: "u", lastLiceseId: "club")
        await settle()
        expect(manual.coordinator.request?.isForced == false, "AUTH先start后仍执行手动密码检查")
        manual.coordinator.dismiss()
        expect(manual.coordinator.request == nil, "非强制稍后可继续")
        let background = Fixture()
        background.driver.suspendCheck = true
        background.coordinator.start(userUID: "u", lastLiceseId: "club")
        await settle()
        background.coordinator.setForegroundActive(false)
        background.driver.suspended?.resume(returning: background.driver.status)
        await settle()
        expect(background.coordinator.request == nil, "后台旧回调不呈现")
        background.driver.suspendCheck = false
        background.coordinator.setForegroundActive(true)
        await settle()
        expect(background.coordinator.request != nil, "回前台重试已取消检查")
        let changed = Fixture()
        changed.coordinator.start(userUID: "u", lastLiceseId: "club")
        await settle()
        changed.coordinator.verifyOldPassword("fixture-old")
        await settle()
        expect(changed.coordinator.oldPasswordVerified, "原密码真实验证后才可输入新密码")
        changed.coordinator.changePassword("abc123!", confirmation: "abc123!", requiresSymbol: false)
        await settle()
        expect(changed.exits == 1 && changed.coordinator.passwordChanged, "修改成功必须退出重新登录")
        expect(changed.driver.calls == ["key", "strength", "key", "old", "key", "reset"], "两次修改阶段均使用新key且遵守旧API顺序")
        expect(changed.driver.parameters.last?["password"] as? String == "cipher", "新密码字段加密")
        changed.coordinator.dismiss()
        expect(changed.coordinator.request != nil, "修改成功不能关闭回主页")
        let exitFailure = Fixture()
        exitFailure.failExit = true
        exitFailure.coordinator.start(userUID: "u", lastLiceseId: "club")
        await settle()
        exitFailure.coordinator.verifyOldPassword("fixture")
        await settle()
        exitFailure.coordinator.changePassword("abc123", confirmation: "abc123", requiresSymbol: false)
        await settle()
        expect(exitFailure.coordinator.passwordChanged && exitFailure.coordinator.request != nil, "清理失败保持修改完成屏障")
        expect(!exitFailure.coordinator.isBusy && exitFailure.coordinator.message?.contains("重试退出") == true, "失败允许重试退出")
        exitFailure.failExit = false
        exitFailure.coordinator.exitToLogin()
        await settle()
        expect(exitFailure.exits == 2, "再次退出完成")
        let reconnect = Fixture()
        reconnect.coordinator.start(userUID: "u", lastLiceseId: "club")
        await settle()
        reconnect.coordinator.verifyOldPassword("fixture")
        await settle()
        reconnect.coordinator.setAuthenticated(false)
        expect(!reconnect.coordinator.oldPasswordVerified, "断线作废原密码验证状态")
        reconnect.coordinator.setAuthenticated(true)
        reconnect.coordinator.changePassword("abc123", confirmation: "abc123", requiresSymbol: false)
        await settle()
        expect(!reconnect.driver.calls.contains("reset"), "重连不能复用断线前验证")
        let mutateBackground = Fixture()
        mutateBackground.driver.suspendReset = true
        mutateBackground.coordinator.start(userUID: "u", lastLiceseId: "club")
        await settle()
        mutateBackground.coordinator.verifyOldPassword("fixture")
        await settle()
        mutateBackground.coordinator.changePassword("abc123", confirmation: "abc123", requiresSymbol: false)
        await settle()
        mutateBackground.coordinator.setForegroundActive(false)
        mutateBackground.driver.resetContinuation?.resume(returning: true)
        await settle()
        expect(mutateBackground.exits == 0, "后台成功不操作页面")
        mutateBackground.coordinator.setForegroundActive(true)
        await settle()
        expect(mutateBackground.coordinator.passwordChanged && mutateBackground.exits == 1, "后台reset成功回前台必须重新登录")
        let mutateSwitch = Fixture()
        mutateSwitch.driver.suspendReset = true
        mutateSwitch.coordinator.start(userUID: "u", lastLiceseId: "club")
        await settle()
        mutateSwitch.coordinator.verifyOldPassword("fixture")
        await settle()
        mutateSwitch.coordinator.changePassword("abc123", confirmation: "abc123", requiresSymbol: false)
        await settle()
        mutateSwitch.coordinator.stop()
        mutateSwitch.coordinator.start(userUID: "next-user", lastLiceseId: "club")
        await settle()
        mutateSwitch.driver.resetContinuation?.resume(returning: true)
        await settle()
        expect(mutateSwitch.exits == 0 && !mutateSwitch.coordinator.passwordChanged, "切账号后旧修改成功不能退出新会话")
        let restartRequirement = Fixture()
        restartRequirement.coordinator.start(userUID: "u", lastLiceseId: "club")
        await settle()
        restartRequirement.coordinator.stop()
        restartRequirement.driver.failure = true
        restartRequirement.coordinator.start(userUID: "u", lastLiceseId: "club")
        await settle()
        expect(restartRequirement.coordinator.request?.isForced == true, "已确认强制要求在重建后检查临时失败时仍必须生效")
        let suiteName = "ddlNew.LoginSecurityChecks.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { preconditionFailure("无法创建隔离测试存储") }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let storage = PasswordSecurityRequirementStore(defaults: defaults)
        let persistentFixture = Fixture()
        let firstProcess = LoginSecurityCoordinator(service: persistentFixture.service, requirementStore: storage, isSessionCurrent: { _, _ in true }, signOut: {})
        firstProcess.start(userUID: "persistent-user", lastLiceseId: "persistent-club")
        await settle()
        expect(storage.load()?.matches(userUID: "persistent-user", lastLiceseId: "persistent-club") == true, "真实AppStorage保存已确认强制要求")
        firstProcess.stop(clearCachedRequirement: false)
        let recreatedStorage = PasswordSecurityRequirementStore(defaults: defaults)
        persistentFixture.driver.failure = true
        let secondProcess = LoginSecurityCoordinator(service: persistentFixture.service, requirementStore: recreatedStorage, isSessionCurrent: { _, _ in true }, signOut: {})
        secondProcess.start(userUID: "persistent-user", lastLiceseId: "persistent-club")
        expect(secondProcess.request?.isForced == true, "新协调器在请求返回前恢复持久屏障")
        await settle()
        expect(secondProcess.request?.isForced == true, "新进程检查失败不能绕过已确认要求")
        secondProcess.stop(clearCachedRequirement: false)
        expect(recreatedStorage.load() != nil, "启动取消和暂时失败不清持久要求")
        recreatedStorage.clear(userUID: "different-user", lastLiceseId: "persistent-club")
        expect(recreatedStorage.load() != nil, "退出其他用户不能清掉本人持久要求")
        secondProcess.start(userUID: "different-user", lastLiceseId: "persistent-club")
        await settle()
        expect(secondProcess.request == nil, "持久要求不锁住其他用户")
        secondProcess.stop(clearCachedRequirement: false)
        secondProcess.start(userUID: "persistent-user", lastLiceseId: "persistent-club")
        await settle()
        secondProcess.stop(clearCachedRequirement: true)
        expect(recreatedStorage.load() == nil, "明确退出清持久要求")
        expect(changed.requirementStore.load() == nil, "真实修改成功清本人强制要求")
        let unownedExit = PasswordSecurityRequirementStore(defaults: defaults)
        unownedExit.save(userUID: "cached-user", lastLiceseId: "cached-club")
        let noRuntimeIdentity = LoginSecurityCoordinator(service: persistentFixture.service, requirementStore: unownedExit, isSessionCurrent: { _, _ in true }, signOut: {})
        noRuntimeIdentity.stop(clearCachedRequirement: true)
        expect(unownedExit.load() == nil, "没有运行时身份的明确退出也清启动标记")
        print("LoginSecurity: \(checks) checks passed")
    }
    static func settle() async { for _ in 0..<25 { await Task.yield() } }
}
