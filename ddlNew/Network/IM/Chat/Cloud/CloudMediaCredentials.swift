// Created by taobo on 2026/10/13.
import Foundation

/// 仅为本次上传持有临时凭据；不参与日志、描述或任何本地持久化。
nonisolated struct CloudMediaCredentials: Sendable {
    let accessKey: String
    let secretKey: String
    let token: String
    let expires: Date
}
