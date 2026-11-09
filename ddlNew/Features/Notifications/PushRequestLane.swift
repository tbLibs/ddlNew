import Foundation

/// 写请求以SDK真实完成/失败回调串行；取消Swift任务不能伪装为取消服务器写入。
/// 底层HTTP/TCP负责运输超时，这里不设置更短的、只取消continuation的超时。
@MainActor final class PushRequestLane {
    private var busy = false
    private var waiting: [CheckedContinuation<Void,Never>] = []
    private func acquire() async {
        if busy { await withCheckedContinuation { waiting.append($0) } }
        else { busy = true }
    }
    private func release() {
        if waiting.isEmpty { busy = false }
        else { waiting.removeFirst().resume() }
    }
    func barrier() async { await acquire(); release() }
    func perform(_ start: (@escaping @MainActor (Result<Bool,Error>)->Void)->Void) async throws -> Bool {
        await acquire()
        defer { release() }
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            var completed = false
            start { result in
                guard !completed else { return }
                completed = true; continuation.resume(with:result)
            }
        }
    }
}
