import Foundation

enum VerificationCheckError: Error { case assertion(String) }

@main
struct LoginVerificationChecks {
    @MainActor static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw VerificationCheckError.assertion(message) }
    }

    @MainActor static func awaitRequest(_ id: UUID, in coordinator: LoginVerificationCoordinator) async throws {
        for _ in 0..<100 {
            if coordinator.request?.id == id { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        throw VerificationCheckError.assertion("challenge was not presented")
    }

    @MainActor static func expectCancellation(_ task: Task<LoginVerificationAnswer, Error>) async throws {
        do {
            _ = try await task.value
            throw VerificationCheckError.assertion("cancelled challenge produced an answer")
        } catch is CancellationError {}
    }

    @MainActor static func main() async throws {
        let coordinator = LoginVerificationCoordinator()
        let first = LoginVerificationRequest(kind: .imageCaptcha)
        let firstTask = Task { try await coordinator.present(first) }
        try await awaitRequest(first.id, in: coordinator)
        coordinator.submit(LoginVerificationAnswer(), for: first.id)
        try require(coordinator.request?.id == first.id, "empty answer closed the sheet")
        coordinator.submit(LoginVerificationAnswer(imageCode: "fixture-code"), for: first.id)
        let firstAnswer = try await firstTask.value
        try require(firstAnswer.imageCode == "fixture-code" && coordinator.request == nil, "answer did not finish the challenge")

        let second = LoginVerificationRequest(kind: .securityCode)
        let secondTask = Task { try await coordinator.present(second) }
        try await Task.sleep(nanoseconds: 5_000_000)
        try require(coordinator.request == nil, "new challenge appeared before the old sheet dismissed")
        coordinator.cancel(requestID: first.id) // 模拟旧弹窗通过 onDisappear 确认已经退出。
        try await awaitRequest(second.id, in: coordinator)
        coordinator.cancel(requestID: first.id)
        coordinator.submit(LoginVerificationAnswer(securityCode: "stale"), for: first.id)
        try require(coordinator.request?.id == second.id, "stale callback changed the current challenge")
        coordinator.request = nil // 模拟用户下滑关闭时，SwiftUI 清空弹窗绑定。
        try await expectCancellation(secondTask)
        coordinator.cancel(requestID: second.id)

        let third = LoginVerificationRequest(kind: .tencentCaptcha)
        let thirdTask = Task { try await coordinator.present(third) }
        try await awaitRequest(third.id, in: coordinator)
        thirdTask.cancel()
        try await expectCancellation(thirdTask)
        try require(coordinator.request == nil, "task cancellation left a sheet open")
        coordinator.cancel(requestID: third.id)

        let finite = LoginVerificationCoordinator(timeoutNanoseconds: 10_000_000)
        let timedRequest = LoginVerificationRequest(kind: .aliyunCaptcha(interactive: false))
        let timedTask = Task { try await finite.present(timedRequest) }
        try await awaitRequest(timedRequest.id, in: finite)
        do {
            _ = try await timedTask.value
            throw VerificationCheckError.assertion("timeout produced an answer")
        } catch let error as LocalizedError {
            try require(error.errorDescription?.contains("超时") == true, "timeout did not explain retry")
        }
        try require(finite.request == nil, "timeout left a sheet open")
        finite.cancel(requestID: timedRequest.id)
        print("Login verification coordinator checks passed")
    }
}
