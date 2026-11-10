//
//  AccountLoginServicing.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

@MainActor
protocol AccountLoginServicing {
    func login(_ input: AccountLoginInput, progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> AccountLoginResponse
    func login(account: String, password: String,
               progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> AccountLoginResponse
}

// 保留已有账号登录的注入边界；新方式要求实现完整入口，不能退回账号参数提交。
extension AccountLoginServicing {
    func login(_ input: AccountLoginInput, progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> AccountLoginResponse {
        guard input.identity.kind == .account, !input.usesCode else { throw AccountLoginError.unsupportedAccountLogin }
        return try await login(account: input.identity.value, password: input.password, progress: progress)
    }
}
