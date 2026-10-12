import Foundation

/// 两个内置桶并发读取；只有解密并通过端点校验的配置才能获胜。
enum OSSHTTPConfigurationClient {
    static func race(lastLiceseId: String) async throws -> OSSRaceWinner {
        guard !lastLiceseId.isEmpty,
              let license = lastLiceseId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            throw OSSNodeRaceError.missingLastLiceseId
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 4
        configuration.timeoutIntervalForResource = 5
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        return try await withThrowingTaskGroup(of: OSSRaceWinner?.self) { group in
            for (index, base) in builtInOSSHTTPBaseURLs.enumerated() {
                guard let url = URL(string: "\(base)/\(license)/nvp") else { continue }
                group.addTask {
                    do {
                        let (data, response) = try await session.data(from: url)
                        try Task<Never, Never>.checkCancellation()
                        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
                        let navigation = try await decode(data, lastLiceseId: lastLiceseId)
                        return OSSRaceWinner(source: index == 0 ? .ossHTTPDomestic : .ossHTTPOverseas,
                                             node: DNSResolvedHost(urlString: url.absoluteString, type: "6"),
                                             navigation: navigation)
                    } catch { return nil }
                }
            }
            defer { group.cancelAll() }
            for try await winner in group { if let winner { return winner } }
            try Task<Never, Never>.checkCancellation()
            throw OSSNodeRaceError.allSourcesFailed
        }
    }

    static func decode(_ data: Data, lastLiceseId: String) throws -> OSSNavigationResult {
        let parsed = try OSSLegacyConfigurationParser.decodeEncrypted(data, lastLiceseId: lastLiceseId)
        var navigation = IMServerListResponseBody()
        navigation.imEndpoints = parsed.http.map { endpoint($0, transport: "http") }
            + parsed.tcp.map { endpoint($0, transport: "tcp") }
        var meta = NavigationMeta()
        meta.navVersion = parsed.version
        navigation.meta = meta
        // 旧 JSON 没有新的 TTL，不伪造有效期；登录重连可以读取过期缓存后主动刷新。
        return try OSSAuthResponseDecoder.navigation(from: navigation)
    }

    private static func endpoint(_ node: OSSLegacyEndpoint, transport: String) -> IMServerEndpoint {
        var endpoint = IMServerEndpoint()
        endpoint.ip = node.host
        endpoint.port = Int32(node.port)
        endpoint.protocols = [transport]
        return endpoint
    }
}
