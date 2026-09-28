//
//  UserSessionStore.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import Combine
import ObjectMapper
import SwiftUI

/// 保存当前用户资料与凭据；有缓存不代表本次启动已通过 TCP AUTH。
@MainActor
final class UserSessionStore: ObservableObject {
    static let shared = UserSessionStore()

    @AppStorage(userInfoAppStorageKey) private var userInfoJSON = ""
    @Published private(set) var currentUser: UserInfo?

    private let credentials = UserCredentialStore.shared

    private init() {}

    @discardableResult
    func save(_ response: AccountLoginResponse, account: String, lastLiceseId: String) throws -> UserSessionCredentials {
        guard response.isValid, let user = response.userInfo,
              let json = Mapper<UserInfo>().toJSONString(user) else { throw UserSessionError.invalidData }
        let previous = try credentials.load()
        // 未下发 deviceSecret 时只允许保留同一用户、同一俱乐部、同一账号的旧凭据。
        let matches = previous?.userUID == user.userUID && previous?.lastLiceseId == lastLiceseId
            && previous?.loginInfo == account
        let deviceSecret = response.deviceSecret.isEmpty && matches ? previous?.deviceSecret ?? "" : response.deviceSecret
        let record = UserSessionCredentials(userUID: user.userUID, token: response.token,
                                           deviceSecret: deviceSecret, loginInfo: account, lastLiceseId: lastLiceseId)
        // Keychain 成功后才发布用户资料，失败不能留下半份新会话。
        try credentials.save(record)
        userInfoJSON = json
        currentUser = user
        return record
    }

    /// 提供成对的缓存读取；仅供后续恢复使用，本步骤不自动登录或跳转。
    func cachedUser() throws -> UserInfo? {
        guard !userInfoJSON.isEmpty else { return nil }
        guard let user = Mapper<UserInfo>().map(JSONString: userInfoJSON),
              let record = try credentials.load(), record.userUID == user.userUID else {
            throw UserSessionError.invalidData
        }
        return user
    }

    func updateToken(_ token: String, userUID: String) throws {
        guard !token.isEmpty, currentUser?.userUID == userUID,
              let record = try credentials.load(), record.userUID == userUID else {
            throw UserSessionError.invalidData
        }
        try credentials.save(record.replacingToken(token))
    }

    func clear() throws {
        // 即使 Keychain 删除失败，也先撤销内存和资料缓存，不能继续显示已登录。
        currentUser = nil
        userInfoJSON = ""
        try credentials.clear()
    }
}
