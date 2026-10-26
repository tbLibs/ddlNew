import Foundation
import CryptoKit

/// 只查询服务器 AAAA 记录，不查询或附带设备公网/网卡地址。
nonisolated enum DNS1DoHClient {
    static func request(domain: String, timestamp: String, endpoint: String, timeout: TimeInterval) throws -> URLRequest {
        let input = dns1AccountId + dns1AccessKeySecret + timestamp + domain + dns1AccessKey
        let signature = SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
        guard var url = URLComponents(string: endpoint) else { throw DNS1Error.unavailable }
        url.queryItems = ["name": domain, "type": "AAAA", "uid": dns1AccountId,
                          "ak": dns1AccessKey, "ts": timestamp, "key": signature]
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let address = url.url else { throw DNS1Error.unavailable }
        var request = URLRequest(url: address, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.setValue("application/dns-json", forHTTPHeaderField: "Accept")
        return request
    }

    static func decode(_ data: Data, response: URLResponse) throws -> [String] {
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 1_048_576 else {
            throw DNS1Error.unavailable
        }
        let result = try JSONDecoder().decode(Response.self, from: data)
        guard result.Status == 0 else { throw DNS1Error.unavailable }
        let records = (result.Answer ?? []).filter { $0.type == 28 }.map(\.data)
        guard !records.isEmpty else { throw DNS1Error.unavailable }
        return records
    }

    static func records(domain: String) async throws -> [String] {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForResource = 5
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        for endpoint in ["https://223.5.5.5/resolve", "https://223.6.6.6/resolve"] {
            try Task.checkCancellation()
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { break }
            do {
                let request = try request(domain: domain, timestamp: String(Int(Date().timeIntervalSince1970)),
                                          endpoint: endpoint, timeout: remaining)
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                return try decode(data, response: response)
            } catch {
                try Task.checkCancellation()
            }
        }
        throw DNS1Error.unavailable
    }

    private struct Response: Decodable {
        let Status: Int
        let Answer: [AnswerRecord]?
    }
    private struct AnswerRecord: Decodable {
        let type: Int
        let data: String
    }
}
