import Combine
import Foundation

/// 管理单次登录验证；上一张弹窗确认退出后，再呈现下一次验证。
@MainActor
final class LoginVerificationCoordinator: ObservableObject, AccountLoginChallengePresenting {
    static let shared = LoginVerificationCoordinator()

    @Published var request: LoginVerificationRequest? {
        didSet {
            // 用户下滑关闭弹窗时，SwiftUI 会清空绑定，同步取消正在等待的登录流程。
            if let oldID = oldValue?.id, oldID != request?.id, activeID == oldID {
                finish(requestID: oldID, result: .failure(CancellationError()))
            }
        }
    }

    private var activeID: UUID?
    private var continuation: CheckedContinuation<LoginVerificationAnswer, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var dismissingID: UUID?
    private let timeoutNanoseconds: UInt64

    init(timeoutNanoseconds: UInt64 = 180_000_000_000) {
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    func present(_ nextRequest: LoginVerificationRequest) async throws -> LoginVerificationAnswer {
        try Task.checkCancellation()
        guard activeID == nil else { throw PresentationError.alreadyPresenting }

        // 服务端可能在上一张弹窗退出动画完成前返回重试要求。
        // 按 UUID 等待 onDisappear 确认退出，旧弹窗的关闭回调不会取消新验证。
        for _ in 0..<40 where dismissingID != nil {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try Task.checkCancellation()
        guard activeID == nil else { throw PresentationError.alreadyPresenting }
        guard dismissingID == nil else {
            // 若任务在弹窗实际出现前取消，可能没有 onDisappear；本次明确报错，
            // 同时释放残留关闭状态，让用户之后重新登录时仍能继续验证。
            dismissingID = nil
            throw PresentationError.alreadyPresenting
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { waiter in
                guard !Task.isCancelled else {
                    waiter.resume(throwing: CancellationError())
                    return
                }
                activeID = nextRequest.id
                continuation = waiter
                request = nextRequest
                timeoutTask = Task { [weak self] in
                    guard let self else { return }
                    do { try await Task.sleep(nanoseconds: self.timeoutNanoseconds) }
                    catch { return }
                    self.finish(requestID: nextRequest.id, result: .failure(PresentationError.timedOut))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(requestID: nextRequest.id) }
        }
    }

    func submit(_ answer: LoginVerificationAnswer, for requestID: UUID) {
        guard activeID == requestID, let request, answer.isValid(for: request.kind) else { return }
        finish(requestID: requestID, result: .success(answer))
    }

    func cancel(requestID: UUID? = nil) {
        if let requestID, dismissingID == requestID {
            dismissingID = nil
        }
        guard let activeID, requestID == nil || requestID == activeID else { return }
        finish(requestID: activeID, result: .failure(CancellationError()))
    }

    private func finish(requestID: UUID, result: Result<LoginVerificationAnswer, Error>) {
        guard activeID == requestID, let waiter = continuation else { return }
        continuation = nil
        activeID = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        dismissingID = requestID
        if request?.id == requestID { request = nil }
        waiter.resume(with: result)
    }

    private enum PresentationError: LocalizedError {
        case alreadyPresenting
        case timedOut

        var errorDescription: String? {
            switch self {
            case .alreadyPresenting: return "验证窗口正在关闭，请稍后重新登录。"
            case .timedOut: return "验证已超时，请重新登录。"
            }
        }
    }
}

private extension LoginVerificationAnswer {
    func isValid(for kind: LoginVerificationKind) -> Bool {
        switch kind {
        case .imageCaptcha: return !imageCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .tencentCaptcha: return !ticket.isEmpty && !randstr.isEmpty
        case .aliyunCaptcha: return !captchaVerifyParam.isEmpty
        case .securityCode: return !securityCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
