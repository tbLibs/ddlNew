//
//  MockContactsClient.swift
//  ddlNew
//
//  Created by taobo on 2026/9/30.
//

import Foundation

/// 用于验证缓存刷新、同步事件和旧账号回调的离线客户端。
@MainActor
final class MockContactsClient: ContactsClient {
    var contacts: [ContactRecord] = []
    var activeUserUID = "user-a"
    var failure: Error?
    var onChange: (@MainActor (ContactsChange) -> Void)?
    private(set) var stopCount = 0
    private(set) var loadCount = 0
    var pendingLoad: CheckedContinuation<[ContactRecord], Error>?
    var suspendNextLoad = false

    func observe(_ onChange: @escaping @MainActor (ContactsChange) -> Void) { self.onChange = onChange }
    func stopObserving() { stopCount += 1; onChange = nil }
    func loadContacts(for userUID: String) async throws -> [ContactRecord] {
        loadCount += 1
        guard userUID == activeUserUID else { throw NSError(domain: "ContactsChecks", code: 1) }
        if let failure { throw failure }
        if suspendNextLoad {
            suspendNextLoad = false
            return try await withCheckedThrowingContinuation { pendingLoad = $0 }
        }
        return contacts
    }
}
