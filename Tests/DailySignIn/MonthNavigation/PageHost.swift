import SwiftUI

// Only external runtime/theme/network boundaries are replaced; page and Store are production.
@MainActor final class ChatRuntime: ObservableObject {
    static let shared = ChatRuntime()
    @Published var revision = UUID()
    var userUID: String? = "test"
    func context(for route: ChatRoute) -> ChatContext? { .init(userUID: "test", tenantID: "test", sessionID: revision, route: route) }
    func isCurrent(_ context: ChatContext) -> Bool { context.sessionID == revision }
    func registerCleanup(owner: AnyObject, cleanup: @escaping () -> Void) {}
}
enum MessagingTheme {
    static let accent = Color.green, background = Color(.systemGroupedBackground), surface = Color(.secondarySystemGroupedBackground), text = Color.primary
}
extension View {
    func messagingFeedbackToast(_ text: String?, trigger: Int = 0) -> some View { self }
}
@MainActor final class SDKDailySignInClient: DailySignInClient {
    func info(context: ChatContext) async throws -> DailySignInInfo { .init(signed: false, todayPoints: "100-200", totalDays: 0, totalPoints: 0, monthDays: 0) }
    func records(month: SignInMonth, context: ChatContext) async throws -> DailySignInRecords {
        guard CommandLine.arguments.contains("--signed-today") else { return .init(total: 0, rows: []) }
        let calendar = SignInMonth.calendar
        let day = min(calendar.component(.day, from: Date()), calendar.range(of: .day, in: .month, for: month.date)!.count)
        let date = calendar.date(byAdding: .day, value: day - 1, to: month.date)!
        return .init(total: 10, rows: [.init(id: 1, date: date, points: 10, dailyPoints: 10, rewardPoints: 0)])
    }
    func points(month: SignInMonth, context: ChatContext) async throws -> DailySignInPoints { .init(used: 0, gained: 0, rows: []) }
    func rule(context: ChatContext) async throws -> DailySignInRule {
        try .parse(["signInSwitch": 0, "signMode": CommandLine.arguments.contains("--continuous") ? 2 : 1, "signMinMoney": 100, "signMaxMoney": 200, "signDayMoney": 10, "signContinueReward": "{\"10\":20,\"2\":3}"])
    }
    func sign(context: ChatContext) async throws -> Int64? { throw DailySignInError.message("系统未开启签到功能") }
    func reminders(sessionID: String, offset: Int, context: ChatContext) throws -> [DailySignInReminder] { [] }
    func cancel() {}
}
@main struct PageHost: App {
    @State private var destination: DailySignInDestination?
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    Button("测试每日签到") { destination = .current() }
                    Button("测试签到助手") { destination = .current(reminderSessionID: "reminders") }
                }
                .navigationTitle("测试入口")
                .navigationDestination(isPresented: Binding(get: { destination != nil }, set: { if !$0 { destination?.close(); destination = nil } })) {
                    if let destination { DailySignInView(destination: destination) }
                }
            }.environment(\.locale, Locale(identifier: "zh-Hans"))
        }
    }
}
