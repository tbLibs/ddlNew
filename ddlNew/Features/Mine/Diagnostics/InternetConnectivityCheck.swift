import Foundation

nonisolated struct InternetConnectivityAttempt: Sendable {
    let address: String
    let passed: Bool
    let milliseconds: Int
}
nonisolated enum InternetConnectivityEvent: Sendable {
    case started(String)
    case finished(InternetConnectivityAttempt)
}

/// 对齐xgd：顺序回退，任一来源通过即停止；不保存响应中的IP或地区数据。
@MainActor enum InternetConnectivityCheck {
    static let addresses = ["https://ipinfo.io/json", "https://ipapi.co/json/",
                            "https://api.ip.sb/geoip", "https://www.google.com/generate_204"]

    static func run(observe: (InternetConnectivityEvent) -> Void = { _ in },
                    request: (URL) async throws -> (Data, Int)) async -> Bool {
        for (index, address) in addresses.enumerated() {
            guard !Task.isCancelled, let url = URL(string: address) else { return false }
            observe(.started(address))
            let started = Date()
            var passed = false
            do {
                let (data, status) = try await request(url)
                guard !Task.isCancelled else { return false }
                if (200..<300).contains(status) {
                    if index == addresses.count - 1 {
                        passed = status == 200 || status == 204
                    } else if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let country = object[index == 0 ? "country" : "country_code"] as? String {
                        passed = !country.isEmpty
                    }
                }
            } catch {
                if Task.isCancelled || error is CancellationError { return false }
            }
            guard !Task.isCancelled else { return false }
            observe(.finished(.init(address: address, passed: passed,
                                   milliseconds: max(0, Int(Date().timeIntervalSince(started) * 1_000)))))
            if passed { return true }
        }
        return false
    }
}
