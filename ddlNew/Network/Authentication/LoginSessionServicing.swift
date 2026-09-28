//
//  LoginSessionServicing.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

@MainActor
protocol LoginSessionServicing {
    func completeLogin(_ response: AccountLoginResponse, account: String,
                       progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws
    func cancelPendingLogin()
    func clearSession() throws
}
