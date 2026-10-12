//
//  ClubStore.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation
import Combine

/// 活动与旧演示账号、拉黑、举报的本地状态；真实身份仍由 SDK AUTH 决定。
@MainActor final class ClubStore: ObservableObject {
    @Published var stage: SessionStage = .splash
    @Published var selectedTab: MemberTab = .home
    @Published private(set) var snapshot = ClubSnapshot()
    @Published var toastMessage = ""
    @Published var showToast = false
    let activities = ClubActivity.samples
    private let repository = ClubRepository()
    private let credentials = LocalCredentialStore()
    private var restored = false
    var memberDisplayName: String { snapshot.activeAccount ?? "林夏" }
    var memberAccountDescription: String {
        "远山户外俱乐部 · \(snapshot.activeAccount ?? "YS****18")"
    }
    private var accountKey: String { snapshot.activeAccount.map { "local:\($0)" } ?? "sample:YS20260018" }
    var blockedContactIDs: Set<String> { snapshot.blockedContactsByAccount?[accountKey] ?? [] }
    var reportRecords: [MessageReport] {
        (snapshot.messageReports ?? []).filter { $0.accountKey == accountKey }
            .sorted { $0.createdAt > $1.createdAt }
    }
    func isBlocked(_ contactID: String) -> Bool { blockedContactIDs.contains(contactID) }
    func hasReported(conversationID: String, messageID: String) -> Bool {
        reportRecords.contains { $0.conversationID == conversationID && $0.messageID == messageID }
    }
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
        selectedTab = .home
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
        notify("注册成功，请登录")
    }
    func signOut(changeClub: Bool = false) async {
        snapshot.signedIn = false
        snapshot.activeAccount = nil
        if changeClub { snapshot.connected = false }
        selectedTab = .home
        await persist()
        stage = changeClub ? .invite : .login
    }
    func deleteAccount() async throws {
        let deleted = ClubSnapshot(connected: false, signedIn: false, participation: [:], accountDeleted: true)
        let previous = try? credentials.load()
        try credentials.delete()
        do { try await repository.save(deleted) }
        catch {
            if let previous { try? credentials.save(previous) }
            throw error
        }
        snapshot = deleted
        selectedTab = .home
        stage = .invite
        notify("账号已注销")
    }
    func blockContact(_ contactID: String) async throws {
        guard ClubContact.samples.contains(where: { $0.id == contactID }), !isBlocked(contactID) else { return }
        var updated = snapshot
        var blocks = updated.blockedContactsByAccount ?? [:]
        blocks[accountKey, default: []].insert(contactID)
        updated.blockedContactsByAccount = blocks
        try await repository.save(updated)
        snapshot = updated
        notify("已加入黑名单")
    }
    func unblockContact(_ contactID: String) async throws {
        guard isBlocked(contactID) else { return }
        var updated = snapshot
        var blocks = updated.blockedContactsByAccount ?? [:]
        blocks[accountKey]?.remove(contactID)
        updated.blockedContactsByAccount = blocks
        try await repository.save(updated)
        snapshot = updated
        notify("已移出黑名单")
    }
    func reportMessage(conversation: ClubMessage, entry: ChatEntry, reason: ReportReason, details: String) async throws -> Bool {
        guard !entry.isOutgoing, !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !hasReported(conversationID: conversation.id, messageID: entry.id) else { return false }
        let report = MessageReport(id: UUID(), accountKey: accountKey, conversationID: conversation.id,
                                   messageID: entry.id, sourceTitle: conversation.title, messageText: entry.text,
                                   reason: reason, details: String(details.prefix(300)), createdAt: Date())
        var updated = snapshot
        updated.messageReports = (updated.messageReports ?? []) + [report]
        try await repository.save(updated)
        snapshot = updated
        return true
    }
    func status(_ activity: ClubActivity) -> Participation { snapshot.participation[activity.id] ?? .available }
    func activities(with states: Set<Participation>) -> [ClubActivity] { activities.filter { states.contains(status($0)) } }
    func register(_ activity: ClubActivity) async {
        guard status(activity) == .available else { return }
        snapshot.participation[activity.id] = activity.capacity > 0 ? .registered : .waiting
        await persist()
    }
    func cancel(_ activity: ClubActivity) async {
        guard [.registered, .waiting].contains(status(activity)) else { return }
        snapshot.participation[activity.id] = .available
        await persist()
        notify("已取消参与")
    }
    func checkIn(_ activity: ClubActivity, code: String) async -> Bool {
        guard status(activity) == .registered, code == activity.checkInCode else { return false }
        snapshot.participation[activity.id] = .checkedIn
        await persist()
        notify("签到成功，享受这次活动吧")
        return true
    }
    func notify(_ text: String) { toastMessage = text; showToast = true }
    private func persist() async {
        do { try await repository.save(snapshot) }
        catch { notify("操作未保存，请重试") }
    }
}
