//
//  OriginalHomeView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 保留原版首页供后续版本参考；当前首页使用 ClubHomeView。
struct OriginalHomeView: View {
    @Environment(\.locale) private var localizationLocale
    @EnvironmentObject private var store: ClubStore
    @EnvironmentObject private var navigation: ActivityNavigation
    @State private var showNews = false
    private var nextActivity: ClubActivity? { store.activities(with: [.registered]).first }
    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    ScreenHeading(eyebrow: L10n.tr("远山户外俱乐部 · 下午好"), title: L10n.tr("\(store.memberDisplayName)，欢迎回来"))
                    IconButton(icon: "bell", label: L10n.tr("查看通知")) { showNews = true }
                }
                ClubCard(padding: 24, highlighted: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        ClubBadge(text: nextActivity == nil ? L10n.tr("发现下一场") : L10n.tr("我的下一场"))
                        Text(nextActivity?.title ?? L10n.tr("一起走进自然")).font(.system(size: 25, weight: .bold))
                        Text(nextActivity.map { L10n.tr("\($0.displayDate) · \($0.displayPlace) · 已报名") } ?? L10n.tr("寻找适合自己的活动，与伙伴一起出发"))
                            .font(.system(size: 12)).foregroundColor(ClubTheme.secondary)
                        if let nextActivity {
                            Button { navigation.open(nextActivity) } label: { Text(L10n.tr("查看参与信息")).padding(.horizontal, 24) }
                                .buttonStyle(ClubButtonStyle()).fixedSize(horizontal: true, vertical: false)
                        } else {
                            NavigationLink(L10n.tr("浏览俱乐部活动"), value: ClubHomeDestination.activities).buttonStyle(ClubButtonStyle())
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle(L10n.tr("会员快捷入口"))
                    HStack(spacing: 9) {
                        NavigationLink(value: RecordKind.registered) {
                            quickEntry(L10n.tr("我的报名"), icon: "calendar", detail: L10n.tr("\(store.activities(with: [.registered]).count)个待参加"))
                        }
                        NavigationLink(value: RecordKind.waiting) {
                            quickEntry(L10n.tr("候补记录"), icon: "clock", detail: L10n.tr("\(store.activities(with: [.waiting]).count)项等待中"))
                        }
                        NavigationLink(value: ActivityRoute.checkInSelection) {
                            quickEntry(L10n.tr("去签到"), icon: "scan", detail: L10n.tr("查看活动"))
                        }
                    }.buttonStyle(.plain)
                }
                VStack(alignment: .leading, spacing: 14) {
                    sectionTitle(L10n.tr("俱乐部公告"))
                    Button { showNews = true } label: {
                        ClubCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(L10n.tr("本月活动报名规则调整")).font(.system(size: 15, weight: .semibold))
                                Text(L10n.tr("取消报名请至少提前12小时，名额将按顺序释放给候补会员。"))
                                    .font(.system(size: 14)).foregroundColor(ClubTheme.secondary).lineSpacing(5)
                            }
                        }
                    }.buttonStyle(.plain)
                }
                VStack(alignment: .leading, spacing: 14) {
                    sectionTitle(L10n.tr("本周推荐"))
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
