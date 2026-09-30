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

    /// 成对读取，避免 Keychain 遗留凭据与另一份用户资料组成错误会话。
    func cachedSession() throws -> UserSessionSnapshot? {
        guard !userInfoJSON.isEmpty else { return nil }
        guard let user = Mapper<UserInfo>().map(JSONString: userInfoJSON),
              !user.userUID.isEmpty, let record = try credentials.load(), record.isValid,
              record.userUID == user.userUID else {
            throw UserSessionError.invalidData
        }
        return UserSessionSnapshot(user: user, credentials: record)
    }

    func cachedUser() throws -> UserInfo? {
        try cachedSession()?.user
    }

    /// AUTH 前恢复用户资料，以便 SDK 刷新 token 时能更新同一用户的 Keychain。
    func restore(_ snapshot: UserSessionSnapshot) throws {
        guard snapshot.credentials.isValid, snapshot.user.userUID == snapshot.credentials.userUID else {
            throw UserSessionError.invalidData
        }
        currentUser = snapshot.user
    }

    /// 临时连接失败只撤销内存中的用户，不删除下次启动需要的持久化凭据。
    func deactivate() {
        currentUser = nil
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
