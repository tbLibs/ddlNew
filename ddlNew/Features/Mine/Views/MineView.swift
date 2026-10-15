//
//  MineView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 个人中心，提供活动记录、设置和更换俱乐部入口。
struct MineView: View {
    @EnvironmentObject private var store: ClubStore
    @State private var showSettings = false
    @State private var showSwitch = false
    @State private var info: InformationPage?
    @State private var showingComplaint = false
    @State private var complaintSubmitted = false
    @State private var feedback: String?
    var body: some View {
        ClubScroll {
            VStack(spacing: 16) {
                ClubCard(padding: 24, highlighted: true) {
                    HStack(spacing: 14) {
                        MemberAvatar()
                        VStack(alignment: .leading, spacing: 9) {
                            Text(store.memberDisplayName).font(.system(size: 23, weight: .bold))
                            Text(store.memberAccountDescription).font(.system(size: 12))
                        }
                    }
                }
                ClubCard {
                    VStack(spacing: 0) {
                        record(.registered, icon: "calendar", detail: "\(store.activities(with: [.registered]).count)个待参加")
                        Divider()
                        record(.waiting, icon: "clock", detail: "\(store.activities(with: [.waiting]).count)项等待中")
                        Divider()
                        record(.checkedIn, icon: "check", detail: "\(store.activities(with: [.checkedIn]).count)次")
                        Divider()
                        record(.past, icon: "users", detail: "查看记录")
                    }
                }
                ClubCard {
                    VStack(spacing: 0) {
                        NavigationLink(value: ClubHomeDestination.club) { ClubMenuRow(title: "当前俱乐部", icon: "shield", detail: "远山户外") }
                        Divider()
                        Button { showSwitch = true } label: { ClubMenuRow(title: "更换俱乐部", icon: "settings") }
                        Divider()
                        Button { info = .privacy } label: { ClubMenuRow(title: "隐私与安全", icon: "lock") }
                        Divider()
                        NavigationLink(value: SafetyRoute.blacklist) { ClubMenuRow(title: "黑名单", icon: "shield") }
                        Divider()
                        Button { feedback = nil; showingComplaint = true } label: { ClubMenuRow(title: "投诉与支持", icon: "messages") }
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 20).padding(.top, 18)
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSettings = true } label: {
                    ClubIcon(name: "settings", size: 21).foregroundStyle(HomeTheme.forest).frame(width: 44, height: 44)
                }.accessibilityLabel("打开设置")
            }
        }
        .toolbarBackground(HomeTheme.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showSettings) { SettingsScreen() }
        .sheet(item: $info) { InformationSheet(page: $0) }
        .sheet(isPresented: $showingComplaint, onDismiss: { if complaintSubmitted { feedback = "投诉已提交"; complaintSubmitted = false } }) {
            ComplaintView(target: .general, targetName: "系统投诉") { complaintSubmitted = true }
        }
        .messagingFeedbackToast(feedback, isEnabled: !showingComplaint)
        .alert("更换俱乐部？", isPresented: $showSwitch) {
            Button("取消", role: .cancel) { }
            Button("更换", role: .destructive) { Task { await store.signOut(changeClub: true) } }
        } message: { Text("将退出当前会员空间，已保存的活动记录会保留。") }
    }
    private func record(_ kind: RecordKind, icon: String, detail: String) -> some View {
        NavigationLink(value: kind) { ClubMenuRow(title: kind.rawValue, icon: icon, detail: detail) }.buttonStyle(.plain)
    }
}
