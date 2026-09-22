import SwiftUI
import Combine

struct MemberTabs: View {
    @EnvironmentObject private var store: ClubStore
    @StateObject private var community = ClubCommunity()

    var body: some View {
        TabView(selection: $store.selectedTab) {
            tab(.home) { HomeScreen() }
            tab(.activities) { ActivitiesScreen() }
            tab(.messages) { MessagesScreen() }
            tab(.contacts) { ContactsScreen() }
            tab(.club) { ClubScreen() }
            tab(.profile) { ProfileScreen() }
        }
        .tint(ClubTheme.teal)
        .environmentObject(community)
    }

    private func tab<Content: View>(_ tab: MemberTab, @ViewBuilder content: () -> Content) -> some View {
        NavigationView {
            ActivityNavigationScope { content().navigationBarHidden(true) }
        }
        .navigationViewStyle(.stack)
        .background {
            if tab == .club || tab == .profile {
                MoreNavigationBarHider()
            }
        }
        .tabItem {
            Label { Text(tab.rawValue) } icon: { Image("club-\(tab.icon)") }
        }
        .badge(tab == .messages ? community.unreadCount : 0)
        .tag(tab)
    }
}

/// The system's More tab already owns a navigation controller. Keep its list
/// navigation intact while hiding the extra bar above a selected overflow tab.
private struct MoreNavigationBarHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) { controller.updateBar() }

    final class Controller: UIViewController {
        private weak var moreNavigationController: UINavigationController?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            DispatchQueue.main.async { [weak self] in self?.updateBar() }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            moreNavigationController?.setNavigationBarHidden(false, animated: false)
        }

        func updateBar() {
            guard isViewLoaded, view.window != nil,
                  let more = tabBarController?.moreNavigationController,
                  more.viewControllers.count > 1 else { return }
            moreNavigationController = more
            more.setNavigationBarHidden(true, animated: false)
        }
    }
}

@MainActor final class ActivityNavigation: ObservableObject {
    @Published var selected: ClubActivity?
    @Published var isPresented = false
    func open(_ activity: ClubActivity) { selected = activity; isPresented = true }
}

/// A stable route survives when a filtered card or the next-activity card changes.
struct ActivityNavigationScope<Content: View>: View {
    @StateObject private var navigation = ActivityNavigation()
    @ViewBuilder let content: Content
    var body: some View {
        content.background {
            NavigationLink(isActive: $navigation.isPresented) {
                if let activity = navigation.selected { ActivityDetailScreen(activity: activity) }
            } label: { EmptyView() }.hidden()
        }.environmentObject(navigation)
    }
}

struct HomeScreen: View {
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
                            Button("浏览俱乐部活动") { store.selectedTab = .activities }.buttonStyle(ClubButtonStyle())
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("会员快捷入口")
                    HStack(spacing: 9) {
                        NavigationLink(destination: RecordsScreen(kind: .registered)) {
                            quickEntry("我的报名", icon: "calendar", detail: "\(store.activities(with: [.registered]).count)个待参加")
                        }
                        NavigationLink(destination: RecordsScreen(kind: .waiting)) {
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

enum ActivityFilter: String, CaseIterable, Identifiable {
    case all = "全部", available = "可报名", registered = "已报名", ended = "已结束"
    var id: Self { self }
}
struct ActivitiesScreen: View {
    @EnvironmentObject private var store: ClubStore
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var filter: ActivityFilter = .all
    private var filtered: [ClubActivity] {
        store.activities.filter { activity in
            let matchesQuery = query.isEmpty || (activity.title + activity.place).localizedCaseInsensitiveContains(query)
            let status = store.status(activity)
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .available: matchesFilter = status == .available
            case .registered: matchesFilter = status == .registered || status == .checkedIn
            case .ended: matchesFilter = status == .ended
            }
            return matchesQuery && matchesFilter
        }
    }
    var body: some View {
        ClubScroll {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeading(eyebrow: "远山户外俱乐部", title: "活动").padding(.bottom, 6)
                HStack(spacing: 10) {
                    ClubIcon(name: "search")
                    TextField("搜索活动或地点", text: $query).focused($searchFocused).submitLabel(.search).font(.system(size: 14)).accessibilityIdentifier("activitySearch")
                    if !query.isEmpty { Button("清除") { query = "" }.font(.caption) }
                }.padding(12).background(ClubTheme.card).clipShape(RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(ClubTheme.border, lineWidth: 1))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(ActivityFilter.allCases) { item in
                            Button { filter = item } label: {
                                Text(item.rawValue).font(.system(size: 14))
                                    .foregroundColor(filter == item ? .white : ClubTheme.secondary)
                                    .padding(.horizontal, 16).frame(minHeight: 38)
                                    .background(filter == item ? ClubTheme.teal : ClubTheme.card)
                                    .clipShape(Capsule()).overlay(Capsule().stroke(filter == item ? .clear : ClubTheme.border, lineWidth: 1))
                            }.accessibilityAddTraits(filter == item ? .isSelected : [])
                        }
                    }
                }
                if filtered.isEmpty {
                    EmptyClubState(title: "暂无符合条件的活动", message: "试试其他关键词，或切换活动分类。")
                } else {
                    LazyVStack(spacing: 12) { ForEach(filtered) { ActivityCard(activity: $0) } }
                }
            }.padding(.horizontal, 20).padding(.top, 18)
        }
        .modifier(ClubKeyboardDismissal(isFocused: searchFocused) { searchFocused = false })
    }
}

struct ActivityCard: View {
    @EnvironmentObject private var store: ClubStore
    @EnvironmentObject private var navigation: ActivityNavigation
    let activity: ClubActivity
    var body: some View {
        Button { navigation.open(activity) } label: {
            ClubCard(padding: 13) {
                HStack(spacing: 13) {
                    RoundedRectangle(cornerRadius: 16).fill(ClubTheme.wash).frame(width: 88, height: 120)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 7) {
                        ClubBadge(text: store.status(activity).title)
                        Text(activity.title).font(.system(size: 14, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                        metadata(icon: "clock", text: activity.date)
                        metadata(icon: "map", text: activity.place)
                        HStack(spacing: 6) {
                            ClubIcon(name: "users", size: 14)
                            Text("伙伴已加入").font(.system(size: 11))
                            Spacer(minLength: 2)
                            ClubIcon(name: "chevron", size: 10)
                            Text("查看").font(.system(size: 11, weight: .semibold))
                        }.foregroundColor(ClubTheme.darkTeal)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }.buttonStyle(.plain).accessibilityIdentifier("activity.\(activity.id)")
    }
    private func metadata(icon: String, text: String) -> some View {
        HStack(spacing: 4) { ClubIcon(name: icon, size: 13); Text(text).font(.system(size: 11)) }.foregroundColor(ClubTheme.secondary)
    }
}

struct ClubScreen: View {
    @State private var info: InformationPage?
    var body: some View {
        ClubScroll {
            VStack(spacing: 28) {
                VStack(spacing: 22) {
                    Text("山").font(.system(size: 31)).foregroundColor(ClubTheme.darkTeal)
                        .frame(width: 84, height: 84).background(ClubTheme.card.opacity(0.85)).clipShape(RoundedRectangle(cornerRadius: 28))
                    Text("远山户外俱乐部").font(.system(size: 30, weight: .bold))
                    Text("每周走进自然，认真生活，也认真交朋友。").font(.system(size: 14)).multilineTextAlignment(.center)
                    HStack {
                        statistic("186", label: "会员")
                        Divider().frame(height: 40)
                        statistic("38", label: "本年活动")
                        Divider().frame(height: 40)
                        statistic("2019", label: "成立")
                    }
                }.padding(.horizontal, 20).padding(.top, 30).padding(.bottom, 25).frame(maxWidth: .infinity).background(ClubTheme.wash)
                VStack(spacing: 16) {
                    ClubCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("如何参与").font(.system(size: 17, weight: .semibold))
                            ForEach(Array(["选择适合自己的俱乐部活动", "阅读参与条件与活动须知", "完成报名或加入候补", "按时到场并完成个人签到"].enumerated()), id: \.element) { index, text in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)").font(.system(size: 12, weight: .semibold)).foregroundColor(ClubTheme.darkTeal)
                                        .frame(width: 30, height: 30).background(ClubTheme.wash).clipShape(Circle())
                                    Text(text).font(.system(size: 14))
                                }.frame(minHeight: 36)
                                if index < 3 { Divider() }
                            }
                        }
                    }
                    ClubCard {
                        VStack(spacing: 0) {
                            infoRow("会员权益", icon: "shield", page: .benefits)
                            Divider()
                            infoRow("活动规则", icon: "note", page: .rules)
                            Divider()
                            infoRow("联系俱乐部", icon: "person", page: .contact)
                        }
                    }
                }.padding(.horizontal, 20)
            }
        }.sheet(item: $info) { InformationSheet(page: $0) }
    }
    private func statistic(_ number: String, label: String) -> some View {
        VStack(spacing: 6) { Text(number).font(.system(size: 16, weight: .medium)); Text(label).font(.system(size: 12)) }.frame(maxWidth: .infinity)
    }
    private func infoRow(_ title: String, icon: String, page: InformationPage) -> some View {
        Button { info = page } label: { ClubMenuRow(title: title, icon: icon) }.buttonStyle(.plain)
    }
}

struct ProfileScreen: View {
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
                        Button { store.selectedTab = .club } label: { ClubMenuRow(title: "当前俱乐部", icon: "shield", detail: "远山户外") }
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
        NavigationLink(destination: RecordsScreen(kind: kind)) { ClubMenuRow(title: kind.rawValue, icon: icon, detail: detail) }.buttonStyle(.plain)
    }
}

struct MemberAvatar: View {
    var body: some View {
        Text("LX").font(.system(size: 12)).foregroundColor(.white).frame(width: 40, height: 40).background(ClubTheme.teal).clipShape(Circle()).accessibilityHidden(true)
    }
}
struct ClubMenuRow: View {
    let title: String
    let icon: String
    var detail: String = ""
    var body: some View {
        HStack(spacing: 10) {
            ClubIcon(name: icon)
            Text(title).font(.system(size: 15))
            Spacer()
            Text(detail).font(.system(size: 11)).foregroundColor(ClubTheme.secondary)
        }.frame(minHeight: 56).contentShape(Rectangle())
    }
}
