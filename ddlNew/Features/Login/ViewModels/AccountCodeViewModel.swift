import Combine
import Foundation

/// 发码成功才启动倒计时；关闭页面或修改接收身份会撤销当前等待结果。
@MainActor final class AccountCodeViewModel: ObservableObject {
    @Published private(set) var isSending = false
    @Published private(set) var feedback: String?
    @Published private var deadlines: [Key: Date] = [:]
    private struct Key: Hashable { let identity: AccountIdentity; let purpose: Int; let scope: String }
    private let service: any AccountCodeServicing
    private let now: () -> Date
    private var task: Task<Void, Never>?
    private var runID = UUID()
    convenience init() { self.init(service: AccountCodeService.shared) }
    init(service: any AccountCodeServicing, now: @escaping () -> Date = Date.init) {
        self.service = service; self.now = now
    }
    func remaining(for identity: AccountIdentity, purpose: AccountCodePurpose, scope: String, at date: Date) -> Int {
        let expiry = deadlines[Key(identity: identity, purpose: purpose.rawValue, scope: scope)] ?? .distantPast
        return max(0, Int(ceil(expiry.timeIntervalSince(date))))
    }
    func send(to identity: AccountIdentity, purpose: AccountCodePurpose, scope: String) {
        guard !isSending, remaining(for: identity, purpose: purpose, scope: scope, at: now()) == 0 else { return }
        cancel(); let run = runID
        isSending = true
        task = Task { [weak self] in
            guard let self else { return }
            defer { if self.runID == run { self.task = nil; self.isSending = false } }
            do {
                try await self.service.send(to: identity, purpose: purpose)
                guard self.runID == run, !Task.isCancelled else { return }
                self.deadlines[Key(identity: identity, purpose: purpose.rawValue, scope: scope)] = self.now().addingTimeInterval(60)
                self.feedback = "验证码已发送，请查看短信"
            } catch is CancellationError {} catch {
                guard self.runID == run, !Task.isCancelled else { return }
                self.feedback = error.localizedDescription
            }
        }
    }
    func cancel() {
        runID = UUID(); task?.cancel(); task = nil; isSending = false; feedback = nil
    }
}
