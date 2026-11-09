import Foundation

nonisolated struct NetworkDiagnosticResult: Identifiable, Sendable {
    let id = UUID()
    let section: String
    let title: String
    let passed: Bool
    let milliseconds: Int
    var targets: [String] = []
}

/// 诊断仅读取本轮来源并探测，不保存导航或改变正式连接。
@MainActor enum NetworkDiagnosticRunner {
    static func run(sources: [DNS1Source],
                    load: @escaping @MainActor (DNS1Source) async throws -> DNS1Payload,
                    probe: @escaping @MainActor (DNS1TCPNode) async throws -> Bool,
                    emit: (NetworkDiagnosticResult) -> Void) async throws {
        for source in sources {
            try Task.checkCancellation()
            let name: String
            switch source.kind {
            case .main: name = "主域"
            case .backup: name = "备域"
            case .bin: name = "BIN"
            case .cache: continue // 诊断不能以缓存掩盖本轮获取失败。
            }
            let start = Date()
            let payload: DNS1Payload
            do { payload = try await load(source) }
            catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                emit(.init(section: "节点获取检测", title: "\(name)：获取失败或超时", passed: false, milliseconds: elapsed(start), targets: [source.address]))
                continue
            }
            try Task.checkCancellation()
            emit(.init(section: "节点获取检测", title: "\(name)：获取到 \(payload.tcp.count) 个节点", passed: !payload.tcp.isEmpty, milliseconds: elapsed(start), targets: [source.address] + payload.tcp.map(\.address)))
            var available = false
            try await withThrowingTaskGroup(of: NetworkDiagnosticResult.self) { group in
                for (index, node) in payload.tcp.enumerated() {
                    group.addTask { @MainActor in
                        try Task.checkCancellation()
                        let started = Date()
                        let passed: Bool
                        do { passed = try await probe(node) }
                        catch {
                            try Task.checkCancellation()
                            if error is CancellationError { throw error }
                            passed = false
                        }
                        try Task.checkCancellation()
                        return .init(section: "服务器连接检测", title: "\(name)节点 \(index + 1)：\(passed ? "TCP / 密钥交换成功" : "连接或密钥交换失败／超时")", passed: passed, milliseconds: elapsed(started), targets: [node.address])
                    }
                }
                for try await result in group {
                    try Task.checkCancellation()
                    available = available || result.passed
                    emit(result)
                }
            }
            if available { return }
        }
    }

    static func elapsed(_ start: Date) -> Int { max(0, Int(Date().timeIntervalSince(start) * 1_000)) }
}
