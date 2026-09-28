//
//  SDKAccountLoginClient.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation
import NoaChatCore
import ObjectMapper

/// 使用 SDK 现有验签、解密和 HTTP 转 TCP 通道，不另写一套登录协议。
@MainActor
final class SDKAccountLoginClient: AccountLoginSDKDriving {
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }

    func fetchEncryptKey() async throws -> String {
        let waiter = SDKLoginRequestWaiter<String>()
        return try await waiter.run {
            self.sdk.authGetEncryptKeySuccess({ data, _ in
                let result: Result<String, AccountLoginError>
                if let key = data as? String, !key.isEmpty {
                    result = .success(key)
                } else {
                    result = .failure(.invalidEncryptKey)
                }
                Task { @MainActor in waiter.finish(result) }
            }, onFailure: { code, message, _ in
                let error = AccountLoginError.businessFailure(code: code, message: message ?? "")
                Task { @MainActor in waiter.finish(.failure(error)) }
            })
        }
    }

    func submit(parameters: [String: Any], captchaChannel: Int) async throws -> AccountLoginResponse {
        // 只装载同一俱乐部、同一账号的设备凭据；不能把上个账号的凭据带进本次请求。
        let credentials = try UserCredentialStore.shared.load()
        let matches = credentials?.loginInfo == parameters["loginInfo"] as? String
            && credentials?.lastLiceseId == sdk.currentLiceseId()
        let waiter = SDKLoginRequestWaiter<AccountLoginResponse>()
        return try await waiter.run {
            self.sdk.configSDKCaptchaChannel(captchaChannel)
            self.sdk.configSDKDeviceSecret(matches ? credentials?.deviceSecret : nil)
            self.sdk.authUserLogin(with: NSMutableDictionary(dictionary: parameters), onSuccess: { data, _ in
                let result: Result<AccountLoginResponse, AccountLoginError>
                // 回调返回的是解密后的 data，不是带 code/data 的外层响应。
                if let json = data as? [String: Any],
                   let response = Mapper<AccountLoginResponse>().map(JSON: json), response.isValid {
                    result = .success(response)
                } else {
                    result = .failure(.invalidResponse)
                }
                Task { @MainActor in waiter.finish(result) }
            }, onFailure: { code, message, _ in
                let error = AccountLoginError.businessFailure(code: code, message: message ?? "")
                Task { @MainActor in waiter.finish(.failure(error)) }
            })
        }
    }
}
