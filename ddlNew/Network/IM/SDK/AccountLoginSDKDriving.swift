//
//  AccountLoginSDKDriving.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Foundation

@MainActor
protocol AccountLoginSDKDriving {
    func checkAccountExists(account: String) async throws -> Bool
    func fetchEncryptKey() async throws -> String
    func submit(parameters: [String: Any], captchaChannel: Int) async throws -> AccountLoginResponse
}
