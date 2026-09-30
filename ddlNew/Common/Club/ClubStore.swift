//
//  ClubStore.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import Foundation
import Combine

/// 活动与俱乐部的本地展示状态；真实登录资格由用户会话与 AUTH 决定。
@MainActor final class ClubStore: ObservableObject {
    @Published var stage: SessionStage = .splash
    @Published var selectedTab: MemberTab = .home
    @Published private(set) var snapshot = ClubSnapshot()
    @Published var toastMessage = ""
    @Published var showToast = false
    let activities = ClubActivity.samples
    private let repository = ClubRepository()
    private var restored = false
    func restore() async {
        guard !restored else { return }
        restored = true
        do { snapshot = try await repository.load() }
        catch {
            // 读取失败时不以空快照覆盖已有数据库。
            restored = false
            stage = .restoreFailed
            return
        }
        stage = snapshot.signedIn ? .member : (snapshot.connected ? .login : .invite)
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
        guard snapshot.accountDeleted != true, card == "YS20260018", password == "123456" else { return false }
        snapshot.signedIn = true
        await persist()
        stage = .member
        return true
    }
    func signOut(changeClub: Bool = false) async {
        snapshot.signedIn = false
        if changeClub { snapshot.connected = false }
        selectedTab = .home
        await persist()
        stage = changeClub ? .invite : .login
    }
    func deleteAccount() async throws {
        let deleted = ClubSnapshot(connected: false, signedIn: false, participation: [:], accountDeleted: true)
        // 先写入数据库，保存失败时不能显示为已注销。
        try await repository.save(deleted)
        snapshot = deleted
        selectedTab = .home
        stage = .invite
        notify("本机账号已注销")
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
        catch { notify("本地保存失败，变更仅保留在本次使用中") }
    }
}
