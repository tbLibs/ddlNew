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
            VStack(alignment: .leading, spacing: 24) {
                header
                hubEntries
                if let activity = featuredActivity {
                    HomeFeaturedActivity(activity: activity, status: store.status(activity)) {
                        navigation.open(activity)
                    }
                }
                quickEntries
                recommendations
                announcement
                Text("去山野，遇见同路人。")
                    .font(.footnote).foregroundStyle(HomeTheme.secondaryText)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 24)
            .frame(maxWidth: HomeTheme.contentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(HomeTheme.background.ignoresSafeArea())
        .sheet(item: $information) { InformationSheet(page: $0) }
        .accessibilityIdentifier("clubHome")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Label("远山户外俱乐部", systemImage: "leaf")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(HomeTheme.forest)
                Spacer(minLength: 0)
                Button { information = .announcements } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 20)).foregroundStyle(HomeTheme.text)
                        .frame(width: 44, height: 44)
                        .background(HomeTheme.surface, in: Circle())
                }
                .buttonStyle(HomePressStyle())
                .accessibilityLabel("查看俱乐部公告")
                .accessibilityIdentifier("home.announcements")
            }
            Text(userName.isEmpty ? "一起出发，走进自然。" : "\(userName)，一起出发。")
                .font(.title.weight(.bold)).foregroundStyle(HomeTheme.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("把日常留在身后，把周末交给山野。")
                .font(.subheadline).foregroundStyle(HomeTheme.secondaryText)
        }
    }

    private var hubEntries: some View {
        // 大字体时改为纵排，保证两个入口的名称与说明完整可见。
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            NavigationLink(value: ClubHomeDestination.activities) {
                HomeHubCard(destination: .activities, detail: "发现下一场精彩")
            }
            .accessibilityHint("浏览、筛选与报名活动")
            .accessibilityIdentifier("home.activities")
            NavigationLink(value: ClubHomeDestination.club) {
                HomeHubCard(destination: .club, detail: "了解我们的俱乐部")
            }
            .accessibilityHint("查看俱乐部介绍与会员权益")
            .accessibilityIdentifier("home.club")
        }
        .buttonStyle(HomePressStyle())
    }

    private var quickEntries: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("我的户外日程")
            layout {
                NavigationLink(destination: RecordsScreen(kind: .registered)) {
                    HomeQuickEntry(title: "我的报名", symbol: "calendar",
                                   detail: "\(store.activities(with: [.registered]).count) 场待参加")
                }
                .accessibilityIdentifier("home.registrations")
                NavigationLink(destination: RecordsScreen(kind: .waiting)) {
                    HomeQuickEntry(title: "候补记录", symbol: "clock",
                                   detail: "\(store.activities(with: [.waiting]).count) 项等待中")
                }
                .accessibilityIdentifier("home.waiting")
                NavigationLink(destination: CheckInSelectionScreen()) {
                    HomeQuickEntry(title: "活动签到", symbol: "qrcode.viewfinder", detail: "到场后签到")
                }
                .accessibilityIdentifier("home.checkIn")
            }
            .buttonStyle(HomePressStyle())
        }
    }

    private var recommendations: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        return VStack(alignment: .leading, spacing: 12) {
            layout {
                sectionTitle("值得一起出发")
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
        }
    }

    private var announcement: some View {
        Button { information = .announcements } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "megaphone")
                    .font(.system(size: 20)).foregroundStyle(HomeTheme.warmAccent)
                    .frame(width: 36, height: 36)
                    .background(HomeTheme.sandSurface, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("俱乐部公告").font(.caption.weight(.semibold)).foregroundStyle(HomeTheme.secondaryText)
                    Text("本月活动报名规则调整").font(.subheadline.weight(.semibold)).foregroundStyle(HomeTheme.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(HomeTheme.secondaryText).padding(.top, 12).accessibilityHidden(true)
            }
            .padding(16).background(HomeTheme.surface, in: RoundedRectangle(cornerRadius: 20))
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
