//
//  ClubHomeView.swift
//  ddlNew
//
//  Created by taobo on 2026/9/29.
//

import SwiftUI
import UIAdapter

/// 会员首页：活动、俱乐部入口在首页聚合，业务页面和报名状态继续复用现有实现。
struct ClubHomeView: View {
    @EnvironmentObject private var store: ClubStore
    @EnvironmentObject private var navigation: ActivityNavigation
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showSwitch = false
    @State private var information: InformationPage?

    /// 由主界面传入已认证用户昵称，预览不需要读取真实会话或 Keychain。
    var userName = ""

    private var featuredActivity: ClubActivity? {
        store.activities(with: [.registered]).first ?? store.activities.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                welcome
                hubEntries
                if let activity = featuredActivity {
                    HomeFeaturedActivity(activity: activity, status: store.status(activity)) {
                        navigation.open(activity)
                    }
                }
                quickEntries
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("俱乐部")
                    club
                }
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
        .navigationTitle("首页")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Label("远山户外俱乐部", systemImage: "leaf")
                    .font(.headline).foregroundStyle(HomeTheme.forest)
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
        .alert("更换俱乐部？", isPresented: $showSwitch) {
            Button("取消", role: .cancel) { }
            Button("更换", role: .destructive) { Task { await store.signOut(changeClub: true) } }
        } message: { Text("将退出当前会员空间，已保存的活动记录会保留。") }
        .accessibilityIdentifier("clubHome")
    }

    /// 欢迎语属于首页内容；俱乐部标识和公告动作交给系统导航工具栏。
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(userName.isEmpty ? "一起出发，走进自然。" : "\(userName)，一起出发。")
                .font(.title.weight(.bold)).foregroundStyle(HomeTheme.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("把日常留在身后，把周末交给山野。")
                .font(.subheadline).foregroundStyle(HomeTheme.secondaryText)
        }
    }

    private var hubEntries: some View {
        NavigationLink(value: ClubHomeDestination.activities) {
            HomeHubCard(destination: .activities, detail: "发现下一场精彩")
        }
        .accessibilityHint("浏览、筛选与报名活动")
        .accessibilityIdentifier("home.activities")
        .buttonStyle(HomePressStyle())
    }

    private var quickEntries: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("我的活动")
            activityRecords
            NavigationLink(value: ActivityRoute.checkInSelection) {
                Label("活动签到", systemImage: "qrcode.viewfinder")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(HomeTheme.forest)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(8)
                    .background(HomeTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            }
            .accessibilityIdentifier("home.checkIn")
        }
        .buttonStyle(HomePressStyle())
    }

    /// 四个既有记录入口不再展示本地演示计数；辅助字号按单列排布。
    private var activityRecords: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8.zoom()),
                            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8.zoom()) {
            record(.registered, symbol: "calendar")
                .accessibilityIdentifier("home.registrations")
            record(.waiting, symbol: "clock")
                .accessibilityIdentifier("home.waiting")
            record(.checkedIn, symbol: "checkmark.square")
                .accessibilityIdentifier("home.checkedIn")
            record(.past, symbol: "flag")
                .accessibilityIdentifier("home.past")
        }
        .padding(8.zoom())
        .background(HomeTheme.surface, in: cardShape)
        .overlay(cardShape.stroke(HomeTheme.border, lineWidth: 1))
    }

    /// 当前俱乐部与更换操作分离，切换由首页确认。
    private var club: some View {
        VStack(spacing: 0) {
            NavigationLink(value: ClubHomeDestination.club) {
                HStack(spacing: 12.zoom()) {
                    Image(systemName: "mountain.2")
                        .font(.system(size: 26.zoom()))
                        .foregroundStyle(HomeTheme.background)
                        .frame(width: 44.zoom(), height: 44.zoom())
                        .background(HomeTheme.forest, in: RoundedRectangle(cornerRadius: 14.zoom()))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4.zoom()) {
                        Text("远山户外").font(.headline)
                        Text("当前俱乐部").font(.caption).foregroundStyle(HomeTheme.secondaryText)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    chevron
                }
                .padding(16.zoom()).contentShape(Rectangle())
            }
            .accessibilityIdentifier("home.club")
            divider.padding(.horizontal, 16.zoom())
            Button { showSwitch = true } label: {
                HStack(spacing: 12.zoom()) {
                    Text("更换俱乐部").font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    chevron
                }
                .foregroundStyle(HomeTheme.forest)
                .frame(minHeight: max(44, 48.zoom()))
                .padding(.horizontal, 16.zoom()).padding(.vertical, 4.zoom())
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("home.switchClub")
        }
        .buttonStyle(HomePressStyle())
        .background(HomeTheme.mintSurface, in: cardShape)
        .overlay(cardShape.stroke(HomeTheme.border, lineWidth: 1))
    }

    private func record(_ kind: RecordKind, symbol: String) -> some View {
        NavigationLink(value: kind) {
            HStack(spacing: 10.zoom()) {
                Image(systemName: symbol).font(.system(size: 19.zoom()))
                    .foregroundStyle(HomeTheme.forest)
                    .frame(width: 34.zoom(), height: 34.zoom())
                    .background(HomeTheme.mintSurface, in: RoundedRectangle(cornerRadius: 11.zoom()))
                    .accessibilityHidden(true)
                Text(kind.rawValue).font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8.zoom()).padding(.vertical, 12.zoom())
            .frame(maxWidth: .infinity, minHeight: max(44, 64.zoom()), alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: 22.zoom(), style: .continuous) }
    private var divider: some View { Rectangle().fill(HomeTheme.border).frame(height: 0.5).accessibilityHidden(true) }
    private var chevron: some View {
        Image(systemName: "chevron.right").font(.caption.weight(.medium))
            .foregroundStyle(HomeTheme.secondaryText).accessibilityHidden(true)
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
