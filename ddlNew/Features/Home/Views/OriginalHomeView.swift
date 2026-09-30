//
//  OriginalHomeView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 保留原版首页供后续版本参考；当前首页使用 ClubHomeView。
struct OriginalHomeView: View {
    @EnvironmentObject private var store: ClubStore
    @EnvironmentObject private var navigation: ActivityNavigation
    @State private var showNews = false
    private var nextActivity: ClubActivity? { store.activities(with: [.registered]).first }
    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    ScreenHeading(eyebrow: "远山户外俱乐部 · 下午好", title: "林夏，欢迎回来")
                    IconButton(icon: "bell", label: "查看通知") { showNews = true }
                }
                ClubCard(padding: 24, highlighted: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        ClubBadge(text: nextActivity == nil ? "发现下一场" : "我的下一场")
                        Text(nextActivity?.title ?? "一起走进自然").font(.system(size: 25, weight: .bold))
                        Text(nextActivity.map { "\($0.date) · \($0.place) · 已报名" } ?? "寻找适合自己的活动，与伙伴一起出发")
                            .font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                        if let nextActivity {
                            Button { navigation.open(nextActivity) } label: { Text("查看参与信息").padding(.horizontal, 24) }
                                .buttonStyle(ClubButtonStyle()).fixedSize(horizontal: true, vertical: false)
                        } else {
                            NavigationLink("浏览俱乐部活动", value: ClubHomeDestination.activities).buttonStyle(ClubButtonStyle())
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("会员快捷入口")
                    HStack(spacing: 9) {
                        NavigationLink(value: RecordKind.registered) {
                            quickEntry("我的报名", icon: "calendar", detail: "\(store.activities(with: [.registered]).count)个待参加")
                        }
                        NavigationLink(value: RecordKind.waiting) {
                            quickEntry("候补记录", icon: "clock", detail: "\(store.activities(with: [.waiting]).count)项等待中")
                        }
                        NavigationLink(destination: CheckInSelectionScreen()) {
                            quickEntry("去签到", icon: "scan", detail: "查看活动")
                        }
                    }.buttonStyle(.plain)
                }
                VStack(alignment: .leading, spacing: 14) {
                    sectionTitle("俱乐部公告")
                    Button { showNews = true } label: {
                        ClubCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("本月活动报名规则调整").font(.system(size: 15, weight: .semibold))
                                Text("取消报名请至少提前12小时，名额将按顺序释放给候补会员。")
                                    .font(.system(size: 14)).foregroundColor(ClubTheme.secondary).lineSpacing(5)
                            }
                        }
                    }.buttonStyle(.plain)
                }
                VStack(alignment: .leading, spacing: 14) {
                    sectionTitle("本周推荐")
                    if let activity = store.activities.first { ActivityCard(activity: activity) }
                }
            }.padding(.horizontal, 20).padding(.top, 18)
        }.sheet(isPresented: $showNews) { InformationSheet(page: .announcements) }
    }
    private func sectionTitle(_ title: String) -> some View { Text(title).font(.system(size: 18, weight: .semibold)) }
    private func quickEntry(_ title: String, icon: String, detail: String) -> some View {
        ClubCard(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) { ClubIcon(name: icon, size: 16); Text(title).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true) }
                Text(detail).font(.system(size: 11)).foregroundColor(ClubTheme.secondary)
            }.frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        }
    }
}
