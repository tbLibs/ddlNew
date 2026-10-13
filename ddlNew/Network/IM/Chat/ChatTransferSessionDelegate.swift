//
//  ChatTransferSessionDelegate.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation

nonisolated final class ChatTransferSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let origin: URL
    /// 证书例外只绑定当前导航上传/下载Origin。
    init(origin: URL) { self.origin = origin }
    /// 上传禁止重定向，令牌不能被转发给其他服务器。
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    /// 保留项目现有同源证书策略，第三方链接使用系统验证。
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let space = challenge.protectionSpace
        guard space.authenticationMethod == NSURLAuthenticationMethodServerTrust, space.host.lowercased() == origin.host?.lowercased(), space.port == (origin.port ?? 443), space.protocol == "https",
              let request = task.currentRequest?.url, request.host == origin.host, request.scheme == origin.scheme, let trust = space.serverTrust else { completionHandler(.performDefaultHandling, nil); return }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

nonisolated final class ChatUploadProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let progress: @MainActor (Double) -> Void
    /// 传输进度只传字节比例，避免泄露请求头与内部路径。
    init(progress: @escaping @MainActor (Double) -> Void) { self.progress = progress }
    /// 字节上送完成仍保留最终服务端确认步骤。
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        Task { @MainActor in progress(min(0.99, Double(totalBytesSent) / Double(totalBytesExpectedToSend))) }
    }
}
