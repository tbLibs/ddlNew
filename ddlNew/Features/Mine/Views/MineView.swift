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
    var body: some View {
        ClubScroll {
            VStack(spacing: 16) {
                HStack {
                    ScreenHeading(eyebrow: "个人中心", title: "我的")
                    IconButton(icon: "settings", label: "打开设置") { showSettings = true }
                }.padding(.bottom, 6)
                ClubCard(padding: 24, highlighted: true) {
                    HStack(spacing: 14) {
                        MemberAvatar()
                        VStack(alignment: .leading, spacing: 9) {
                            Text("林夏").font(.system(size: 23, weight: .bold))
                            Text("远山户外俱乐部 · YS****18").font(.system(size: 12))
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
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 20).padding(.top, 18)
        }
        .sheet(isPresented: $showSettings) { SettingsScreen() }
        .sheet(item: $info) { InformationSheet(page: $0) }
        .alert("更换俱乐部？", isPresented: $showSwitch) {
            Button("取消", role: .cancel) { }
            Button("更换", role: .destructive) { Task { await store.signOut(changeClub: true) } }
        } message: { Text("将退出当前会员空间，已保存的活动记录会保留。") }
    }
    private func record(_ kind: RecordKind, icon: String, detail: String) -> some View {
        NavigationLink(value: kind) { ClubMenuRow(title: kind.rawValue, icon: icon, detail: detail) }.buttonStyle(.plain)
    }
}
