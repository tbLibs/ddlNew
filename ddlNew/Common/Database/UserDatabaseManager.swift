//
//  UserDatabaseManager.swift
//  ddlNew
//
//  Created by taobo on 2026/9/28.
//

import NoaChatCore

/// 用户数据库入口。沿用 SDK 的用户目录、加密和建表逻辑，不再打开第二套 WCDB 数据库。
@MainActor
final class UserDatabaseManager {
    static let shared = UserDatabaseManager()

    private init() {}

    /// configSDKUserWith 已同步建库；这里只检查结果，不重复建库或触发 AUTH。
    func requireReady(for userUID: String) throws {
        let sdk = NoaIMSDKManager.sharedTool()
        guard sdk.myUserID() == userUID, sdk.isUserDatabaseReady() else {
            throw UserSessionError.databaseNotReady
        }
    }

    /// 关闭当前用户数据库但保留历史数据文件，供该用户下次登录复用。
    func close() {
        NoaIMSDKManager.sharedTool().closeUserDatabase()
    }
}
