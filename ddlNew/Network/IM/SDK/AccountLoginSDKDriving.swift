//
//  AccountLoginSDKDriving.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

@MainActor
/// 隔离 SDK 登录请求，返回成功响应后统一交给会话与 AUTH 服务完成认证。
protocol AccountLoginSDKDriving {
    func checkAccountExists(account: String) async throws -> Bool
    /// 获取单次提交使用的新密钥，不缓存或复用前一次请求的密钥。
    func fetchEncryptKey() async throws -> String
    /// 返回可显示的图片数据，验证码答案仍由用户输入并交给服务端校验。
    func fetchImageCaptcha(account: String) async throws -> Data
    func submit(parameters: [String: Any], captchaChannel: Int) async throws -> AccountLoginResponse
    /// 参数包含内部 scKey、新密钥和加密安全码，均不记录或持久化。
    func submitSecurityCode(parameters: [String: Any]) async throws -> AccountLoginResponse
    /// 本轮图文回退结束后，恢复原连接的验证码渠道。
    func restoreCaptchaChannel(_ channel: Int)
}
