import SwiftUI

@MainActor struct DailySignInDestination: Identifiable {
    let id = UUID()
    let context: ChatContext
    let reminderSessionID: String?
    let store: DailySignInStore
    /// 从所属导航栈真正返回时关闭；push子页不会关闭共享Store。
    func close() { store.close() }
    @MainActor static func current(reminderSessionID: String? = nil) -> Self? {
        guard let uid = ChatRuntime.shared.userUID,
              let context = ChatRuntime.shared.context(for: ChatRoute(id: uid, kind: .single, title: "", avatarURL: "")) else { return nil }
        return Self(context: context, reminderSessionID: reminderSessionID,
                    store: DailySignInStore(context: context, client: SDKDailySignInClient(), isCurrent: { ChatRuntime.shared.isCurrent($0) }))
    }
}

/// 复用入口所属导航栈，两个入口均以push展示。
struct DailySignInView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var runtime = ChatRuntime.shared
    @StateObject private var store: DailySignInStore
    let destination: DailySignInDestination
    init(destination: DailySignInDestination) {
        self.destination = destination
        _store = StateObject(wrappedValue: destination.store)
    }
    var body: some View {
        Group {
            if let sessionID = destination.reminderSessionID { reminderList(sessionID) }
            else { DailySignInDashboard(store: store) }
        }
        .tint(MessagingTheme.accent)
        .onAppear {
            let owner = store
            runtime.registerCleanup(owner: owner) { [weak owner] in owner?.close() }
        }
        .onChange(of: runtime.revision) { _ in
            if !runtime.isCurrent(destination.context) { store.close(); dismiss() }
        }
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
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                LabeledContent(L10n.tr("当前日期")) {
                    Text(timeline.date, format: .dateTime.year().month().day().weekday(.wide))
                        .accessibilityIdentifier("dailySignIn.currentDate")
                }.font(.subheadline).foregroundStyle(.secondary)
            }
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
        }
        // List默认automatic按钮会让整行响应多个按钮，必须分别处理左右点击。
        .buttonStyle(.borderless)
        .disabled(store.busy)
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
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            calendarGrid(today: timeline.date)
        }
    }
    private func calendarGrid(today: Date) -> some View {
        let todayDay = SignInMonth(date: today) == month ? calendar.component(.day, from: today) : nil
        return VStack(spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 10) {
                // 负数ID与下方日期ID分开，避免LazyVGrid把首周日期与星期标题复用。
                ForEach(-7..<0, id: \.self) { index in
                    Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + index + 7) % 7]).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(0..<(offset + days), id: \.self) { index in
                    let day = index - offset + 1
                    let isToday = day == todayDay
                    let isSigned = signedDays.contains(day)
                    VStack(spacing: 4) {
                        Text(day > 0 ? String(day) : " ")
                            .font(.callout.weight(isToday ? .bold : .regular)).monospacedDigit()
                        HStack(spacing: 2) {
                            if isToday { Text(L10n.tr("今天")).lineLimit(1).minimumScaleFactor(0.6) }
                            if isSigned { Image(systemName: "checkmark.circle.fill") }
                        }.font(.system(size: 10, weight: .semibold)).frame(height: 14)
                    }.frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(isToday || isSigned ? MessagingTheme.accent : MessagingTheme.text)
                        .background(isSigned ? MessagingTheme.accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(isToday ? MessagingTheme.accent : Color.clear, lineWidth: 1.5)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(day > 0 ? L10n.tr("\(day)日") : "")
                        .accessibilityValue([isToday ? L10n.tr("今天") : nil, isSigned ? L10n.tr("已签到") : nil].compactMap { $0 }.joined(separator: "，"))
                        .accessibilityIdentifier("dailySignIn.calendar.\(month.year)-\(month.month)-\(day)")
                        .accessibilityHidden(day <= 0)
                }
            }
            Label(L10n.tr("已签到"), systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(MessagingTheme.accent)
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
            if rule.content.isEmpty { Text(L10n.tr("签到暂未开放")) }
            else {
                Section { Text(rule.content).lineSpacing(5) }
                if rule.mode == 2 {
                    Section {
                        HStack {
                            Text(L10n.tr("当月连续签到成功天数"))
                            Spacer()
                            Text(L10n.tr("奖励积分"))
                        }.font(.subheadline.bold())
                        ForEach(rule.rewards) { reward in
                            HStack { Text(L10n.tr("\(reward.days)天")); Spacer(); Text(L10n.tr("\(reward.points)积分")) }
                        }
                    }
                }
            }
        }.navigationTitle(L10n.tr("签到规则")).navigationBarTitleDisplayMode(.inline)
    }
}
