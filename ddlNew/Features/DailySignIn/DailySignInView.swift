import SwiftUI

struct DailySignInDestination: Identifiable {
    let id = UUID()
    let context: ChatContext
    let reminderSessionID: String?
    @MainActor static func current(reminderSessionID: String? = nil) -> Self? {
        guard let uid = ChatRuntime.shared.userUID,
              let context = ChatRuntime.shared.context(for: ChatRoute(id: uid, kind: .single, title: "", avatarURL: "")) else { return nil }
        return Self(context: context, reminderSessionID: reminderSessionID)
    }
}

/// 两个入口共享独立导航容器，避免读取或修改首页的导航实现。
struct DailySignInView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var runtime = ChatRuntime.shared
    @StateObject private var store: DailySignInStore
    let destination: DailySignInDestination
    init(destination: DailySignInDestination) {
        self.destination = destination
        _store = StateObject(wrappedValue: DailySignInStore(context: destination.context, client: SDKDailySignInClient(), isCurrent: { ChatRuntime.shared.isCurrent($0) }))
    }
    var body: some View {
        NavigationStack {
            Group {
                if let sessionID = destination.reminderSessionID { reminderList(sessionID) }
                else { DailySignInDashboard(store: store) }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("关闭")) { dismiss() } } }
        }
        .tint(MessagingTheme.accent)
        .onAppear {
            let owner = store
            runtime.registerCleanup(owner: owner) { [weak owner] in owner?.close() }
        }
        .onChange(of: runtime.revision) { _ in
            if !runtime.isCurrent(destination.context) { store.close(); dismiss() }
        }
        .onDisappear { store.close() }
    }

    private func reminderList(_ sessionID: String) -> some View {
        List {
            Section {
                NavigationLink { DailySignInDashboard(store: store) } label: {
                    Label(L10n.tr("去签到"), systemImage: "checkmark.seal")
                        .frame(minHeight: 44)
                }
            }
            if store.reminders.isEmpty { Text(L10n.tr("暂无签到提醒")).foregroundStyle(.secondary) }
            ForEach(store.reminders) { reminder in
                VStack(alignment: .leading, spacing: 12) {
                    Text(reminder.date, format: .dateTime.year().month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                    Label(L10n.tr("签到提醒"), systemImage: "calendar.badge.clock").font(.headline)
                    NavigationLink { DailySignInDashboard(store: store) } label: { Text(L10n.tr("去签到")).frame(minHeight: 44) }
                }.padding(.vertical, 8)
            }
            if let error = store.error { Text(error).foregroundStyle(.red) }
            if store.hasMoreReminders {
                Button(L10n.tr("加载更多")) { store.loadReminders(sessionID: sessionID) }.frame(minHeight: 44)
            }
        }
        .navigationTitle(L10n.tr("签到助手")).navigationBarTitleDisplayMode(.inline)
        .task { store.loadReminders(sessionID: sessionID, reset: true) }
        .refreshable { store.loadReminders(sessionID: sessionID, reset: true) }
    }
}

private struct DailySignInDashboard: View {
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var phase
    @ObservedObject var store: DailySignInStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let info = store.info {
                    summary(info)
                    monthSelector
                    DailySignInCalendar(month: store.month, records: store.records?.rows ?? [])
                    NavigationLink { DailySignInHistory(store: store, isPoints: false) } label: { menu(L10n.tr("签到记录"), icon: "calendar") }
                    NavigationLink { DailySignInHistory(store: store, isPoints: true) } label: { menu(L10n.tr("积分明细"), icon: "list.bullet.rectangle") }
                    if let rule = store.rule {
                        NavigationLink { DailySignInRules(rule: rule) } label: { menu(L10n.tr("签到规则"), icon: "text.book.closed") }
                    }
                }
                if store.busy { ProgressView().frame(maxWidth: .infinity).accessibilityLabel(L10n.tr("正在加载")) }
                if let error = store.error {
                    Text(error).foregroundStyle(.red).font(.callout)
                    Button(L10n.tr("重新加载")) { Task { await store.refresh() } }.disabled(store.busy).frame(minHeight: 44)
                }
            }.padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background(MessagingTheme.background)
        .navigationTitle(L10n.tr("每日签到")).navigationBarTitleDisplayMode(.inline)
        .task { await store.refresh() }
        .refreshable { await store.refresh() }
        .onChange(of: phase) { value in if value == .active { Task { await store.refresh() } } }
        .messagingFeedbackToast(store.feedback, trigger: store.feedbackRevision)
    }
    private func summary(_ info: DailySignInInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.tr("签到领积分")).font(.title2.bold())
            LabeledContent(L10n.tr("累计签到"), value: L10n.tr("\(info.totalDays)天"))
            LabeledContent(L10n.tr("累计签到积分"), value: String(info.totalPoints))
            Divider()
            Text(store.signed ? L10n.tr("今日已领积分") : L10n.tr("今日可领积分")).foregroundStyle(.secondary)
            Text(info.todayPoints).font(.largeTitle.bold()).monospacedDigit()
            Button { Task { await store.sign() } } label: {
                Text(store.signed ? L10n.tr("今日已签到") : L10n.tr("立即签到"))
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
            }.buttonStyle(.borderedProminent).disabled(!store.canSign).accessibilityIdentifier("dailySignIn.submit")
            Text(L10n.tr("本月已累计签到\(info.monthDays)天")).font(.footnote).foregroundStyle(.secondary)
        }.padding(20).background(MessagingTheme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
    private var monthSelector: some View { DailySignInMonthSelector(store: store) }
    private func menu(_ title: String, icon: String) -> some View {
        HStack { Label(title, systemImage: icon); Spacer(); Image(systemName: "chevron.right").font(.caption) }
            .foregroundStyle(MessagingTheme.text).frame(minHeight: 44).padding(12)
            .background(MessagingTheme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct DailySignInMonthSelector: View {
    @Environment(\.locale) private var locale
    @ObservedObject var store: DailySignInStore
    var body: some View {
        HStack {
            Button { Task { await store.refresh(month: store.month.shifted(-1)) } } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel(L10n.tr("上个月"))
            Spacer(minLength: 0)
            Text(store.month.date, format: .dateTime.year().month(.wide)).font(.headline)
            Spacer(minLength: 0)
            Button { Task { await store.refresh(month: store.month.shifted(1)) } } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .accessibilityLabel(L10n.tr("下个月")).disabled(store.month.date >= SignInMonth().date)
        }.disabled(store.busy)
    }
}

private struct DailySignInCalendar: View {
    @Environment(\.locale) private var locale
    let month: SignInMonth
    let records: [DailySignInRecord]
    private var calendar: Calendar { var c = SignInMonth.calendar; c.locale = locale; return c }
    private var offset: Int { (calendar.component(.weekday, from: month.date) - calendar.firstWeekday + 7) % 7 }
    private var days: Int { calendar.range(of: .day, in: .month, for: month.date)?.count ?? 0 }
    private var signedDays: Set<Int> { Set(records.filter { SignInMonth(date: $0.date) == month }.map { calendar.component(.day, from: $0.date) }) }
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 10) {
            ForEach(0..<7, id: \.self) { index in
                Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + index) % 7]).font(.caption).foregroundStyle(.secondary)
            }
            ForEach(0..<(offset + days), id: \.self) { index in
                let day = index - offset + 1
                VStack(spacing: 3) {
                    Text(day > 0 ? String(day) : " ").font(.callout).monospacedDigit()
                    Image(systemName: "checkmark").font(.caption2.bold()).opacity(signedDays.contains(day) ? 1 : 0)
                }.frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(signedDays.contains(day) ? MessagingTheme.accent : MessagingTheme.text)
                    .background(signedDays.contains(day) ? MessagingTheme.accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(day > 0 ? L10n.tr("\(day)日") + (signedDays.contains(day) ? L10n.tr("已签到") : "") : "")
                    .accessibilityHidden(day <= 0)
            }
        }.padding(12).background(MessagingTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct DailySignInHistory: View {
    @Environment(\.locale) private var locale
    @ObservedObject var store: DailySignInStore
    let isPoints: Bool
    var body: some View {
        List {
            DailySignInMonthSelector(store: store)
            if store.busy { ProgressView() }
            if let error = store.error {
                Text(error).foregroundStyle(.red)
                Button(L10n.tr("重新加载")) { Task { await store.refresh() } }.disabled(store.busy)
            }
            if isPoints, let points = store.points {
                Text(L10n.tr("获得：\(points.gained) · 使用：\(points.used)"))
                if points.rows.isEmpty { Text(L10n.tr("本月暂无积分记录")).foregroundStyle(.secondary) }
                ForEach(points.rows) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(row.date, format: .dateTime.year().month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                        HStack { Text(row.title); Spacer(); Text(row.amount).monospacedDigit() }
                    }.padding(.vertical, 6)
                }
            } else if let records = store.records {
                Text(L10n.tr("累计获得：\(records.total)积分"))
                if records.rows.isEmpty { Text(L10n.tr("本月暂无签到记录")).foregroundStyle(.secondary) }
                ForEach(records.rows) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(row.date, format: .dateTime.year().month().day()); Spacer(); Text("+\(row.points)").monospacedDigit() }
                        Text(L10n.tr("日签积分：\(row.dailyPoints) · 连签奖励：\(row.rewardPoints)")).font(.footnote).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }
            }
        }.navigationTitle(isPoints ? L10n.tr("积分明细") : L10n.tr("签到记录"))
            .navigationBarTitleDisplayMode(.inline).refreshable { await store.refresh() }
    }
}

private struct DailySignInRules: View {
    @Environment(\.locale) private var locale
    let rule: DailySignInRule
    var body: some View {
        List {
            if !rule.enabled { Text(L10n.tr("签到暂未开放")) }
            else {
                Section {
                    if rule.mode == 1 { Text(L10n.tr("每日签到可获得\(rule.minimum)～\(rule.maximum)积分。")) }
                    else { Text(L10n.tr("每日签到可获得\(rule.daily)积分，连续签到可获得额外奖励。")) }
                    Text(L10n.tr("每日最多签到一次，积分仅限本人使用，不可转移。"))
                    if rule.mode == 2 { Text(L10n.tr("连签中断后保留已有积分，连续天数重新计算；达到最高连签档位后，每日继续获得该档奖励。")) }
                }
                if !rule.description.isEmpty { Section { Text(rule.description) } }
                if !rule.rewards.isEmpty {
                    Section(L10n.tr("连续签到奖励")) {
                        ForEach(rule.rewards) { reward in
                            HStack { Text(L10n.tr("\(reward.days)天")); Spacer(); Text(L10n.tr("\(reward.points)积分")) }
                        }
                    }
                }
            }
        }.navigationTitle(L10n.tr("签到规则")).navigationBarTitleDisplayMode(.inline)
    }
}
