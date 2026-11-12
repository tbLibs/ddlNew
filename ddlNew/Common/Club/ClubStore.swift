//
//  ClubStore.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation
import Combine

/// 根页面与旧演示账号的本地状态；真实身份仍由 SDK AUTH 决定。
@MainActor final class ClubStore: ObservableObject {
    @Published var stage: SessionStage = .splash
    @Published var selectedTab: MemberTab = .messages
    @Published private(set) var snapshot = ClubSnapshot()
    @Published var toastMessage = ""
    @Published var showToast = false
    private let repository = ClubRepository()
    private let credentials = LocalCredentialStore()
    private var restored = false
    func restore() async {
        guard !restored else { return }
        restored = true
        do { snapshot = try await repository.load() }
        catch {
            // Do not overwrite an unreadable database with a fresh account state.
            restored = false
            stage = .restoreFailed
            return
        }
        stage = snapshot.signedIn ? .member : (snapshot.connected ? .login : .invite)
    }
    /// The current connection flow fetches system configuration before opening login.
    func prepareForConnectedLogin() async throws {
        var updated = try await repository.load()
        try Task.checkCancellation()
        updated.connected = true
        updated.signedIn = false
        updated.activeAccount = nil
        try await repository.save(updated)
        try Task.checkCancellation()
        snapshot = updated
        restored = true
        selectedTab = .messages
        stage = .login
    }
    func connect(code: String) async -> Bool {
        try? await Task.sleep(nanoseconds: 750_000_000)
        guard code == "100001" else { return false }
        snapshot.connected = true
        await persist()
        stage = .login
        return true
    }
    func login(card: String, password: String) async -> Bool {
        try? await Task.sleep(nanoseconds: 500_000_000)
        let local = try? credentials.load()
        let localMatch = snapshot.localAccount == card && local?.account == card && local?.password == password
        let sampleMatch = snapshot.accountDeleted != true && card == "YS20260018" && password == "123456"
        guard localMatch || sampleMatch else { return false }
        snapshot.signedIn = true
        snapshot.activeAccount = localMatch ? card : nil
        await persist()
        stage = .member
        return true
    }
    func registerAccount(account: String, password: String) async throws {
        guard snapshot.connected, !account.isEmpty, !password.isEmpty else { throw LocalCredentialError.invalidData }
        let previous = try credentials.load()
        try credentials.save(LocalCredentials(account: account, password: password))
        var updated = snapshot
        updated.localAccount = account
        updated.activeAccount = nil
        updated.signedIn = false
        do { try await repository.save(updated) }
        catch {
            if let previous { try? credentials.save(previous) }
            else { try? credentials.delete() }
            throw error
        }
        snapshot = updated
        stage = .login
        notify(L10n.tr("注册成功，请登录"))
    }
    func signOut(changeClub: Bool = false) async {
        snapshot.signedIn = false
        snapshot.activeAccount = nil
        if changeClub { snapshot.connected = false }
        selectedTab = .messages
        await persist()
        stage = changeClub ? .invite : .login
    }
    func deleteAccount() async throws {
        let deleted = ClubSnapshot(connected: false, signedIn: false, accountDeleted: true)
        let previous = try? credentials.load()
        try credentials.delete()
        do { try await repository.save(deleted) }
        catch {
            if let previous { try? credentials.save(previous) }
            throw error
        }
        snapshot = deleted
        selectedTab = .messages
        stage = .invite
        notify(L10n.tr("账号已注销"))
    }
    func notify(_ text: String) { toastMessage = text; showToast = true }
    private func persist() async {
        do { try await repository.save(snapshot) }
        catch { notify(L10n.tr("操作未保存，请重试")) }
    }
}
