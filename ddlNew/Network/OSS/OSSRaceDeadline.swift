import Foundation

/// 子请求必须支持取消；任务组退出时同时收回计时器和未获胜请求。
nonisolated enum OSSRaceDeadline {
    static func run<Value: Sendable>(seconds: TimeInterval,
                                    operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
        try await withThrowingTaskGroup(of: Value.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task<Never, Never>.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw OSSNodeRaceError.timedOut
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw OSSNodeRaceError.allSourcesFailed }
            return first
        }
    }
}
