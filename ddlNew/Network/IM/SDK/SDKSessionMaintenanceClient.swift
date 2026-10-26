//
//  SDKSessionMaintenanceClient.swift
//  ddlNew
//
//  Created by taobo on 2026/10/13.
//

import Foundation
import NoaChatCore

/// 复用 SDK 的签名、解密及 HTTP 转 TCP 请求，输出只包含业务字典。
@MainActor
final class SDKSessionMaintenanceClient {
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }

    func profile(userUID: String, onRejected: @escaping @MainActor (Int, String) -> Void = { _, _ in }) async throws -> String {
        try await dictionary(onRejected: onRejected) { success, failure in
            self.sdk.getUserInfo(with: NSMutableDictionary(dictionary: ["userUid": userUID]),
                                 onSuccess: success, onFailure: failure)
        }
    }

    func roleAuthority(userUID: String, onRejected: @escaping @MainActor (Int, String) -> Void = { _, _ in }) async throws -> String {
        try await dictionary(onRejected: onRejected) { success, failure in
            self.sdk.userGetRoleAuthorityList(with: NSMutableDictionary(dictionary: ["userUid": userUID]),
                                              onSuccess: success, onFailure: failure)
        }
    }

    /// 等待有上限；服务端退出失败不能阻止本地退出，也不能重试到下一用户会话。
    func logout(userUID: String, token: String) async {
        let waiter = SDKLoginRequestWaiter<Bool>(timeoutNanoseconds: 2_000_000_000)
        do {
            _ = try await waiter.run {
                self.sdk.authUserLogout(with: NSMutableDictionary(dictionary: ["userUid": userUID, "tokenLogin": token]),
                    onSuccess: { _, _ in Task { @MainActor in waiter.finish(.success(true)) } },
                    onFailure: { _, _, _ in Task { @MainActor in waiter.finish(.success(false)) } })
            }
        } catch { /* 无网络或等待超时仍继续本地清理，不记录 Token。 */ }
    }

    private func dictionary(onRejected: @escaping @MainActor (Int, String) -> Void, _ start: (@escaping LingIMSuccessCallback,
                                      @escaping LingIMFailureCallback) -> Void) async throws -> String {
        let waiter = SDKLoginRequestWaiter<String>()
        return try await waiter.run {
            start({ data, _ in
                // String 为可传递快照，避免跨并发边界捕获 SDK 的可变 NSDictionary。
                let json = (data as? [String: Any]).flatMap { value -> String? in
                    guard JSONSerialization.isValidJSONObject(value),
                          let bytes = try? JSONSerialization.data(withJSONObject: value) else { return nil }
                    return String(data: bytes, encoding: .utf8)
                }
                Task { @MainActor in
                    if let json { waiter.finish(.success(json)) }
                    else { waiter.finish(.failure(.invalidResponse)) }
                }
            }, { code, message, _ in
                let safeMessage = code == 90018 ? LoginSecurityNotice.whitelistAddress(from: message ?? "") : ""
                Task { @MainActor in
                    // 明确封禁即使在后台也撤销原会话；调用方核对 UID/邀请码/会话轮次。
                    onRejected(code, safeMessage)
                    waiter.finish(.failure(.businessFailure(code: code, message: safeMessage)))
                }
            })
        }
    }
}
