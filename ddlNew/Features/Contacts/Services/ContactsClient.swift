//
//  ContactsClient.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

/// 通讯录与 SDK 的边界，可在验证中替换为不访问网络和用户数据库的客户端。
@MainActor
protocol ContactsClient: AnyObject {
    func observe(_ onChange: @escaping @MainActor (ContactsChange) -> Void)
    func stopObserving()
    func loadContacts(for userUID: String) async throws -> [ContactRecord]
}
