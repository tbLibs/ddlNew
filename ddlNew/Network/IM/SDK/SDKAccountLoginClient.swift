//
//  SDKAccountLoginClient.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation
import UIKit
import NoaChatCore
import ObjectMapper

/// 使用 SDK 现有验签、解密和 HTTP 转 TCP 通道，不另写一套登录协议。
@MainActor
final class SDKAccountLoginClient: AccountLoginSDKDriving {
    private var sdk: NoaIMSDKManager { NoaIMSDKManager.sharedTool() }

    func restoreCaptchaChannel(_ channel: Int) {
        sdk.configSDKCaptchaChannel(channel)
    }

    /// 与旧项目一致，先检查账号；服务端字段名为 userExit。
    func checkAccountExists(account: String) async throws -> Bool {
        let parameters: [String: Any] = ["loginInfo": account, "loginType": 1, "areaCode": ""]
        let startedAt = Date()
        let waiter = SDKLoginRequestWaiter<Bool>()
        return try await waiter.run {
            self.sdk.authUserExistAndHasPwd(with: NSMutableDictionary(dictionary: parameters), onSuccess: { data, _ in
                let result: Result<Bool, AccountLoginError>
                if let json = data as? [String: Any],
                   let exists = (json["userExit"] as? NSNumber)?.boolValue
                    ?? (json["userExit"] as? NSString)?.boolValue {
                    result = .success(exists)
                } else {
                    result = .failure(.invalidResponse)
                }
                Task { @MainActor in waiter.finish(result) }
            }, onFailure: { code, message, traceID in
                let error = AccountLoginError.businessFailure(code: code, message: message ?? "")
                Task { @MainActor in
                    let elapsed = String(format: "%.2f", Date().timeIntervalSince(startedAt))
                    debugPrint("[账号登录][检查账号] SDK请求失败，code=\(code)，耗时=\(elapsed)s，traceId=\(traceID ?? "无")")
                    waiter.finish(.failure(error))
                }
            })
        }
    }

    func fetchEncryptKey() async throws -> String {
        let startedAt = Date()
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
            }, onFailure: { code, message, traceID in
                let error = AccountLoginError.businessFailure(code: code, message: message ?? "")
                Task { @MainActor in
                    let elapsed = String(format: "%.2f", Date().timeIntervalSince(startedAt))
                    debugPrint("[账号登录][领取密钥] SDK请求失败，code=\(code)，耗时=\(elapsed)s，traceId=\(traceID ?? "无")")
                    waiter.finish(.failure(error))
                }
            })
        }
    }

    func fetchImageCaptcha(account: String) async throws -> Data {
        let parameters: [String: Any] = ["loginName": account, "type": 0]
        let waiter = SDKLoginRequestWaiter<Data>()
        return try await waiter.run {
            self.sdk.authGetImgVerCode(with: NSMutableDictionary(dictionary: parameters), onSuccess: { data, _ in
                Task { @MainActor in
                    guard let value = data as? String,
                          let image = self.captchaImageData(value) else {
                        waiter.finish(.failure(.invalidResponse))
                        return
                    }
                    waiter.finish(.success(image))
                }
            }, onFailure: { code, _, _ in
                // 验证码响应仅用于显示图片，错误提示和日志不包含响应内容。
                Task { @MainActor in
                    waiter.finish(.failure(.businessFailure(code: code, message: "获取验证码失败，请重新登录")))
                }
            })
        }
    }

    /// 兼容服务端返回的 Base64 图片，以及旧部署返回字符后由客户端绘制图片的协议。
    private func captchaImageData(_ value: String) -> Data? {
        let encoded = value.hasPrefix("data:image/") ? String(value.split(separator: ",", maxSplits: 1).last ?? "") : value
        if let data = Data(base64Encoded: encoded), UIImage(data: data) != nil { return data }
        guard !value.isEmpty, value.count <= 12,
              value.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) else { return nil }
        let size = CGSize(width: 180, height: 60)
        return UIGraphicsImageRenderer(size: size).image { renderer in
            UIColor(white: 0.97, alpha: 1).setFill()
            renderer.fill(CGRect(origin: .zero, size: size))
            let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple]
            for (index, character) in value.enumerated() {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 26), .foregroundColor: colors[index % colors.count]
                ]
                (String(character) as NSString).draw(at: CGPoint(x: 8 + CGFloat(index) * (164 / CGFloat(value.count)), y: 14),
                                                    withAttributes: attributes)
            }
        }.pngData()
    }

    /// 仅提交本轮加密安全码；成功响应交给已有会话与 AUTH 链路处理。
    func submitSecurityCode(parameters: [String: Any]) async throws -> AccountLoginResponse {
        let waiter = SDKLoginRequestWaiter<AccountLoginResponse>()
        return try await waiter.run {
            self.sdk.authSecurityCodeLogin(with: NSMutableDictionary(dictionary: parameters), onSuccess: { data, _ in
                let result: Result<AccountLoginResponse, AccountLoginError>
                if let json = data as? [String: Any],
                   let response = Mapper<AccountLoginResponse>().map(JSON: json), response.isValid {
                    result = .success(response)
                } else {
                    result = .failure(.invalidResponse)
                }
                Task { @MainActor in waiter.finish(result) }
            }, onFailure: { code, message, _ in
                // 白名单错误仅传递实际 IP；其他响应可能携带短期验证凭据，不转发原始消息。
                let notice = code == 90018 ? LoginSecurityNotice.whitelistAddress(from: message ?? "") : "安全码验证失败，请重新登录"
                Task { @MainActor in
                    waiter.finish(.failure(.businessFailure(code: code, message: notice)))
                }
            })
        }
    }

    func submit(parameters: [String: Any], captchaChannel: Int) async throws -> AccountLoginResponse {
        // 只装载同一俱乐部、同一账号的设备凭据；不能把上个账号的凭据带进本次请求。
        let credentials = try UserCredentialStore.shared.load()
        let matches = credentials?.loginInfo == parameters["loginInfo"] as? String
            && credentials?.lastLiceseId == sdk.currentLiceseId()
        let startedAt = Date()
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
            }, onFailure: { code, message, traceID in
                let error = AccountLoginError.businessFailure(code: code, message: message ?? "")
                Task { @MainActor in
                    let elapsed = String(format: "%.2f", Date().timeIntervalSince(startedAt))
                    debugPrint("[账号登录][提交登录] SDK请求失败，code=\(code)，耗时=\(elapsed)s，captchaChannel=\(captchaChannel)，traceId=\(traceID ?? "无")")
                    waiter.finish(.failure(error))
                }
            })
        }
    }
}
