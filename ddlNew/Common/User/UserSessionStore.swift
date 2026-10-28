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
    /// 资料写入版本使早于主动保存发起的维护读取失效。
    private(set) var profileRevision = UUID()

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

    /// 资料与凭据必须成对且属于同一俱乐部；旧账号缓存不能跨入口恢复。
    func loadCachedSession(lastLiceseId: String) throws -> (user: UserInfo, credentials: UserSessionCredentials)? {
        let record = try credentials.load()
        if userInfoJSON.isEmpty, record == nil { return nil }
        guard let record, record.isValid, record.lastLiceseId == lastLiceseId,
              let user = Mapper<UserInfo>().map(JSONString: userInfoJSON),
              !user.userUID.isEmpty, record.userUID == user.userUID else {
            throw UserSessionError.invalidData
        }
        return (user, record)
    }

    /// 认证期间允许保存 SDK 刷新的 Token；根路由仍须等待 AUTH 成功。
    func activateCachedUser(_ user: UserInfo) {
        currentUser = user
    }

    /// 暂时断网或取消恢复只撤销内存资格，不删除下次启动可重试的凭据。
    func revokeCurrentUser() {
        currentUser = nil
    }

    func updateToken(_ token: String, userUID: String) throws {
        guard !token.isEmpty, currentUser?.userUID == userUID,
              let record = try credentials.load(), record.userUID == userUID else {
            throw UserSessionError.invalidData
        }
        try credentials.save(record.replacingToken(token))
    }

    /// 资料接口可能只返回部分字段；合并资料而不改写 Token 或设备凭据。
    func updateProfile(_ fields: [String: Any], userUID: String, lastLiceseId: String) throws {
        guard let user = currentUser, user.userUID == userUID,
              let record = try credentials.load(), record.userUID == userUID,
              record.lastLiceseId == lastLiceseId,
              fields["userUID"] == nil || fields["userUID"] as? String == userUID else {
            throw UserSessionError.invalidData
        }
        guard let updated = user.applyingProfile(fields, expectedUID: userUID),
              let json = Mapper<UserInfo>().toJSONString(updated) else { throw UserSessionError.invalidData }
        userInfoJSON = json
        profileRevision = UUID()
        currentUser = updated
    }

    func clear() throws {
        // 即使 Keychain 删除失败，也先撤销内存和资料缓存，不能继续显示已登录。
        currentUser = nil
        userInfoJSON = ""
        try credentials.clear()
    }
}
