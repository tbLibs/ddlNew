import SwiftUI

@MainActor final class MonthClient: DailySignInClient {
    func info(context: ChatContext) async throws -> DailySignInInfo { .init(signed: false, todayPoints: "100-200", totalDays: 0, totalPoints: 0, monthDays: 0) }
    func records(month: SignInMonth, context: ChatContext) async throws -> DailySignInRecords { .init(total: 0, rows: []) }
    func points(month: SignInMonth, context: ChatContext) async throws -> DailySignInPoints { .init(used: 0, gained: 0, rows: []) }
    func rule(context: ChatContext) async throws -> DailySignInRule { .init(enabled: false, mode: 0, daily: 0, minimum: 0, maximum: 0, description: "", rewards: []) }
    func sign(context: ChatContext) async throws -> Int64? { nil }
    func reminders(sessionID: String, offset: Int, context: ChatContext) throws -> [DailySignInReminder] { [] }
    func cancel() {}
}

@main struct MonthHost: App {
    @StateObject private var store = DailySignInStore(context: .init(userUID: "test", tenantID: "test", sessionID: UUID(), route: .init(id: "test", kind: .single, title: "", avatarURL: "")), client: MonthClient(), isCurrent: { _ in true })
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                VStack {
                    Text("\(store.month.year)-\(store.month.month)").accessibilityIdentifier("selectedMonth")
                    List { DailySignInMonthSelector(store: store) }
                }
                .navigationTitle(CommandLine.arguments.contains("--points") ? "积分明细" : "签到记录")
            }.environment(\.locale, Locale(identifier: "zh-Hans"))
        }
    }
}
