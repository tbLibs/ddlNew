//
//  AccountLoginServicing.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

@MainActor
protocol AccountLoginServicing {
    func login(account: String, password: String,
               progress: @escaping @MainActor (AccountLoginPhase) -> Void) async throws -> AccountLoginResponse
}
