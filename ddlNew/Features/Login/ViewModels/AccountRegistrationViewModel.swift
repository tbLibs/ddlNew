import Combine
import Foundation

/// 只有真实注册响应和 AUTH 都完成后才进入主界面。
@MainActor
final class AccountRegistrationViewModel: ObservableObject {
    @Published private(set) var phase: AccountLoginPhase = .idle
    /// 注册响应已成功时，AUTH 失败应引导回登录页，不能让用户重复创建账号。
    @Published private(set) var accountWasRegistered = false
    private let service: any AccountRegistrationServicing
    private let session: any LoginSessionServicing
    private let onSucceeded: @MainActor () -> Void
    private var task: Task<Void, Never>?
    private var runID = UUID()

    convenience init() {
        self.init(service: AccountRegistrationService.shared, session: LoginSessionService.shared)
    }

    init(service: any AccountRegistrationServicing,
         session: any LoginSessionServicing,
         onSucceeded: @escaping @MainActor () -> Void = { AppSessionRouter.enterMain() }) {
        self.service = service
        self.session = session
        self.onSucceeded = onSucceeded
    }

    func register(_ input: AccountRegistrationInput) {
        guard !phase.isBusy, phase != .succeeded, !accountWasRegistered else { return }
        cancel()
        let id = runID
        phase = .checkingAccount
        task = Task { [weak self] in
            guard let self else { return }
            defer { if self.runID == id { self.task = nil } }
            do {
                let response = try await self.service.register(input) { [weak self] phase in
                    guard let self, self.runID == id, !Task.isCancelled else { return }
                    self.phase = phase
                }
                try Task<Never, Never>.checkCancellation()
                guard self.runID == id else { return }
                self.accountWasRegistered = true
                try await self.session.completeLogin(response, account: input.account) { [weak self] phase in
                    guard let self, self.runID == id, !Task.isCancelled else { return }
                    self.phase = phase
                }
                try Task<Never, Never>.checkCancellation()
                guard self.runID == id else { return }
                self.task = nil
                self.phase = .succeeded
                self.onSucceeded()
            } catch is CancellationError {
                if self.runID == id { self.phase = .idle }
            } catch {
                guard self.runID == id, !Task.isCancelled else { return }
                self.phase = .failed(self.accountWasRegistered
                    ? "账号已注册，请返回登录页登录。\(error.localizedDescription)"
                    : error.localizedDescription)
            }
        }
    }

    func cancel() {
        guard task != nil || phase != .succeeded else { return }
        runID = UUID()
        task?.cancel()
        task = nil
        // 仅在本注册页面已开始建立会话时取消，避免退出空表单影响其他登录。
        if [.savingSession, .configuringSDK, .authenticating].contains(phase) { session.cancelPendingLogin() }
        phase = .idle
    }
}
