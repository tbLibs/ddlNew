import Foundation
import Combine

/// 页面状态绑定完整AUTH身份。月切换串行提交，旧请求和退出回包不会串到新页面。
@MainActor final class DailySignInStore: ObservableObject {
    @Published private(set) var info: DailySignInInfo?
    @Published private(set) var rule: DailySignInRule?
    @Published private(set) var records: DailySignInRecords?
    @Published private(set) var points: DailySignInPoints?
    @Published private(set) var month = SignInMonth()
    @Published private(set) var busy = false
    @Published private(set) var feedback: String?
    @Published private(set) var feedbackRevision = 0
    @Published private(set) var error: String?
    @Published private(set) var reminders: [DailySignInReminder] = []
    @Published private(set) var hasMoreReminders = true
    private var reminderOffset = 0
    private var revision = UUID()
    private var closed = false
    // 写入已受理但刷新失败时仍禁止本页再次提交；完整刷新后采用服务端状态。
    private var acceptedDay: Date?
    private let client: any DailySignInClient
    let context: ChatContext
    private let isCurrent: (ChatContext) -> Bool

    init(context: ChatContext, client: any DailySignInClient, isCurrent: @escaping (ChatContext) -> Bool) {
        self.context = context; self.client = client; self.isCurrent = isCurrent
    }
    var signed: Bool { acceptedDay == SignInMonth.calendar.startOfDay(for: Date()) || info?.signed == true }
    // 与xgd一致，签到开关由写接口判定；规则快照不能代替服务端受理结果。
    var canSign: Bool { !closed && !busy && isCurrent(context) && info != nil && !signed && error == nil }

    func refresh(month newMonth: SignInMonth? = nil) async {
        guard !busy, !closed, isCurrent(context) else { return }
        let target = newMonth ?? month, run = revision
        busy = true; error = nil; feedback = nil
        defer { if revision == run { busy = false } }
        do { try await load(target, run: run) }
        catch { report(error, run: run) }
    }

    private func load(_ target: SignInMonth, run: UUID) async throws {
        let newInfo = try await client.info(context: context); try validate(run)
        let newRule = try await client.rule(context: context); try validate(run)
        let newRecords = try await client.records(month: target, context: context); try validate(run)
        let newPoints = try await client.points(month: target, context: context); try validate(run)
        // 同一月完整结果一起发布，错误时保留旧月和旧快照，避免标题与数据错配。
        info = newInfo; rule = newRule; records = newRecords; points = newPoints; month = target
        if newInfo.signed { acceptedDay = SignInMonth.calendar.startOfDay(for: Date()) }
    }

    func sign() async {
        guard canSign else { return }
        let run = revision
        busy = true; error = nil; feedback = nil
        defer { if revision == run { busy = false } }
        do {
            let reward = try await client.sign(context: context); try validate(run)
            acceptedDay = SignInMonth.calendar.startOfDay(for: Date())
            feedback = reward.map { L10n.tr("签到成功，获得\($0)积分") } ?? L10n.tr("签到成功")
            feedbackRevision += 1
            do { try await load(SignInMonth(), run: run) }
            catch {
                try validate(run)
                self.error = L10n.tr("签到已受理，数据刷新失败，请重新加载")
            }
        } catch {
            guard !closed, revision == run, isCurrent(context), !(error is CancellationError) else { return }
            // 包括“系统未开启签到功能”在内的服务端失败原文作为Toast展示；失败可再次点击。
            feedback = error.localizedDescription
            feedbackRevision += 1
        }
    }

    func loadReminders(sessionID: String, reset: Bool = false) {
        guard !closed, isCurrent(context), reset || hasMoreReminders else { return }
        do {
            let offset = reset ? 0 : reminderOffset
            let rows = try client.reminders(sessionID: sessionID, offset: offset, context: context)
            if reset { reminders = []; reminderOffset = 0 }
            let known = Set(reminders.map(\.id))
            reminders += rows.filter { !known.contains($0.id) }
            reminderOffset += rows.count; hasMoreReminders = rows.count == 15; error = nil
        } catch { report(error, run: revision) }
    }

    func close() {
        closed = true; revision = UUID(); client.cancel(); busy = false
        info = nil; rule = nil; records = nil; points = nil; reminders = []; error = nil; feedback = nil
    }
    private func validate(_ run: UUID) throws {
        try Task.checkCancellation()
        guard !closed, revision == run, isCurrent(context) else { throw CancellationError() }
    }
    private func report(_ error: Error, run: UUID) {
        guard !closed, run == revision, isCurrent(context), !(error is CancellationError) else { return }
        self.error = error.localizedDescription
    }
}
