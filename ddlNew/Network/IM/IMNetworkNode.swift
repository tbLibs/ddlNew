import Foundation

/// 重连及网络质量检测共用的服务器地址。
nonisolated struct OSSLegacyEndpoint: Equatable, Sendable {
    let host: String
    let port: UInt16
}
