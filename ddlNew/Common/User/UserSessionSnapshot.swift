//
//  UserSessionSnapshot.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

/// 成对读取的用户资料和会话凭据；仍需本次连接 AUTH 成功才能进入主页。
nonisolated struct UserSessionSnapshot: Sendable {
    let user: UserInfo
    let credentials: UserSessionCredentials
}
