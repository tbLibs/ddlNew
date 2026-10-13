// Created by taobo on 2026/10/13.
import Foundation

/// 云对象地址采用系统TLS验证，不继承导航节点的自签证书例外。
nonisolated final class CloudUploadSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let progress: @MainActor (Double) -> Void
    /// 只暴露传输比例，不记录请求头、签名或临时凭据。
    init(progress: @escaping @MainActor (Double) -> Void) { self.progress = progress }
    /// 禁止自动重定向，供应商鉴权不得传播到其他地址。
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    /// 上送字节完成仍等待HTTP业务确认，不能提前宣称消息发送成功。
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        Task { @MainActor in progress(min(0.99, Double(totalBytesSent) / Double(totalBytesExpectedToSend))) }
    }
}
