//
//  ClubHomeView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI

/// 会员首页：活动、俱乐部入口在首页聚合，业务页面和报名状态继续复用现有实现。
struct ClubHomeView: View {
    @EnvironmentObject private var store: ClubStore
    @EnvironmentObject private var navigation: ActivityNavigation
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var information: InformationPage?

    /// 由主界面传入已认证用户昵称，预览不需要读取真实会话或 Keychain。
    var userName = ""

    private var featuredActivity: ClubActivity? {
        store.activities(with: [.registered]).first ?? store.activities.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("首页").font(.largeTitle.weight(.bold)).foregroundStyle(HomeTheme.text)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 12)
                    .accessibilityAddTraits(.isHeader)
                welcome
                if let activity = featuredActivity {
                    HomeFeaturedActivity(activity: activity, status: store.status(activity)) {
                        navigation.open(activity)
                    }
                }
                quickEntries
                recommendations
                hubEntries
                announcement
            }
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 24)
            .frame(maxWidth: HomeTheme.contentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(HomeTheme.surface.ignoresSafeArea())
        .navigationTitle("首页")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 标题在正文稳定展示，导航标题仍用于子页返回文本。
            ToolbarItem(placement: .principal) {
                Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { information = .announcements } label: {
                    Image(systemName: "bell").font(.system(size: 20)).foregroundStyle(HomeTheme.text)
                        .frame(width: 44, height: 44)
                }.accessibilityLabel("查看俱乐部公告").accessibilityIdentifier("home.announcements")
            }
        }
        .toolbarBackground(HomeTheme.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(item: $information) { InformationSheet(page: $0) }
        .accessibilityIdentifier("clubHome")
    }

    /// 俱乐部标识位于正文标题下方，公告动作保留在系统导航工具栏。
    private var welcome: some View {
        Text("远山户外俱乐部").font(.subheadline).foregroundStyle(HomeTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 24)
    }

    private var hubEntries: some View {
        HStack {
            NavigationLink(value: ClubHomeDestination.club) {
                Text("俱乐部介绍").font(.subheadline.weight(.medium)).frame(minHeight: 44)
            }.accessibilityIdentifier("home.club")
            Spacer()
            NavigationLink(value: ClubHomeDestination.activities) {
                Text("全部活动").font(.subheadline.weight(.medium)).frame(minHeight: 44)
            }.accessibilityIdentifier("home.activities")
        }.foregroundStyle(HomeTheme.forest).padding(.top, 20)
    }

    private var quickEntries: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return VStack(alignment: .leading, spacing: 12) {
            layout {
                NavigationLink(value: RecordKind.registered) {
                    HomeQuickEntry(title: "我的报名", symbol: "calendar",
                                   detail: "\(store.activities(with: [.registered]).count) 场待参加")
                }
                .accessibilityIdentifier("home.registrations")
                NavigationLink(value: RecordKind.waiting) {
                    HomeQuickEntry(title: "候补记录", symbol: "clock",
                                   detail: "\(store.activities(with: [.waiting]).count) 项等待中")
                }
                .accessibilityIdentifier("home.waiting")
                NavigationLink(value: ActivityRoute.checkInSelection) {
                    HomeQuickEntry(title: "活动签到", symbol: "qrcode.viewfinder", detail: "到场后签到")
                }
                .accessibilityIdentifier("home.checkIn")
            }
            .buttonStyle(HomePressStyle())
        }
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(MessagingTheme.divider).frame(height: 1) }
    }

    private var recommendations: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        return VStack(alignment: .leading, spacing: 0) {
            layout {
                sectionTitle("近期活动")
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }
                NavigationLink(value: ClubHomeDestination.activities) {
                    Label("全部活动", systemImage: "arrow.right")
                        .font(.subheadline.weight(.medium)).foregroundStyle(HomeTheme.forest)
                        .frame(minHeight: 44).fixedSize(horizontal: false, vertical: true)
                }.buttonStyle(HomePressStyle())
            }
            ForEach(store.activities.filter { $0.id != featuredActivity?.id }.prefix(2)) { activity in
                HomeActivityRow(activity: activity, status: store.status(activity)) { navigation.open(activity) }
            }
        }.padding(.top, 16)
    }

    private var announcement: some View {
        Button { information = .announcements } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "megaphone")
                    .font(.system(size: 20)).foregroundStyle(HomeTheme.warmAccent)
                    .frame(width: 36, height: 36)

                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("俱乐部公告").font(.caption.weight(.semibold)).foregroundStyle(HomeTheme.secondaryText)
                    Text("本月活动报名规则调整").font(.subheadline.weight(.semibold)).foregroundStyle(HomeTheme.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(HomeTheme.secondaryText).padding(.top, 12).accessibilityHidden(true)
            }
            .padding(.vertical, 16)
            .overlay(alignment: .top) { Rectangle().fill(MessagingTheme.divider).frame(height: 1) }
        }
        .buttonStyle(HomePressStyle())
        .accessibilityIdentifier("home.announcementCard")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.headline).foregroundStyle(HomeTheme.text).accessibilityAddTraits(.isHeader)
    }
}

#Preview("会员首页") {
    ActivityNavigationScope { ClubHomeView(userName: "小山") }
    .environmentObject(ClubStore())
}

#Preview("大字体首页") {
    ActivityNavigationScope { ClubHomeView() }
    .environmentObject(ClubStore())
    .environment(\.dynamicTypeSize, .accessibility3)
}
