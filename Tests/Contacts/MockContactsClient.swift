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
    var remoteContacts: [ContactRecord] = []
    var refreshCount = 0
    var refreshFailure: Error?
    var profileWaiters: [String: CheckedContinuation<Void, Error>] = [:]
    var suspendRefreshes = false

    func refreshProfile(_ friendUID: String, for userUID: String) async throws {
        refreshCount += 1
        if let refreshFailure { throw refreshFailure }
        if suspendRefreshes {
            try await withCheckedThrowingContinuation { profileWaiters[friendUID] = $0 }
        }
        try Task.checkCancellation()
        guard userUID == activeUserUID else { throw CancellationError() }
        if let fresh = remoteContacts.first(where: { $0.id == friendUID }),
           let index = contacts.firstIndex(where: { $0.id == friendUID }) { contacts[index] = fresh }
    }

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
