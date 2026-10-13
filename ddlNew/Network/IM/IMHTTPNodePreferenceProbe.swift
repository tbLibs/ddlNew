//
//  IMHTTPNodePreferenceProbe.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import Security

nonisolated enum IMHTTPNodePreferenceURL {
    static func base(_ address: String) -> URL? {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = value.contains("://") ? value : "https://\(value)"
        guard var components = URLComponents(string: raw),
              components.scheme?.lowercased() == "https" || components.scheme?.lowercased() == "http",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/",
              !value.contains(where: { $0.isWhitespace }),
              components.port.map({ $0 > 0 && $0 <= 65535 }) ?? true else { return nil }
        components.scheme = "https"
        components.host = host.lowercased()
        components.path = ""
        if components.port == 443 { components.port = nil }
        return components.url
    }

    static func sameOrigin(_ first: URL, _ second: URL) -> Bool {
        first.scheme?.lowercased() == second.scheme?.lowercased()
            && first.host?.lowercased() == second.host?.lowercased()
            && (first.port ?? 443) == (second.port ?? 443)
    }

    /// 收到真正的成功 HTTP 响应才能记录 RTT；跳转、证书错误和其他传输错误都算失败。
    static func succeeded(response: URLResponse, requestedURL: URL) -> Bool {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
              let returned = response.url, sameOrigin(returned, requestedURL),
              returned.path == requestedURL.path else { return false }
        return true
    }
}

@MainActor
enum IMHTTPNodePreferenceProbe {
    static func measure(_ node: URL, path: String) async throws -> Double? {
        guard let normalized = IMHTTPNodePreferenceURL.base(node.absoluteString), normalized == node else { return nil }
        let delegate = IMHTTPNodePreferenceSessionDelegate(origin: node)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 3
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let url = node.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let started = ProcessInfo.processInfo.systemUptime
        let (_, response) = try await session.data(for: request)
        try Task<Never, Never>.checkCancellation()
        guard IMHTTPNodePreferenceURL.succeeded(response: response, requestedURL: url) else { return nil }
        return (ProcessInfo.processInfo.systemUptime - started) * 1000
    }
}

/// 临时证书例外只作用于本次导航候选的同源请求，不能扩散到跳转目标或其他 Session。
nonisolated private final class IMHTTPNodePreferenceSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let origin: URL
    init(origin: URL) { self.origin = origin }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let space = challenge.protectionSpace
        guard space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              space.host.lowercased() == origin.host?.lowercased(),
              space.port == (origin.port ?? 443), space.protocol == "https",
              let requestURL = task.currentRequest?.url,
              IMHTTPNodePreferenceURL.sameOrigin(origin, requestURL), let trust = space.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
