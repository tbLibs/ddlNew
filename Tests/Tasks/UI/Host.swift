import SwiftUI

@main struct TaskTestHost: App {
    @StateObject private var store = PersonalTaskStore.shared
    init() {
        L10n.use(.simplifiedChinese)
        if ProcessInfo.processInfo.arguments.contains("--reset-tasks"),
           let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            // Only this anonymous test app's sandbox, never the shipping app's data.
            try? FileManager.default.removeItem(at: support.appendingPathComponent("PersonalTasks"))
        }
        PersonalTaskStore.shared.activate(tenantID: "ui-test-tenant", userUID: "ui-test-user")
    }
    var body: some Scene {
        WindowGroup {
            NavigationStack { PersonalTasksView().id(store.epoch) }
                .environment(\.locale, Locale(identifier: "zh-Hans"))
        }
    }
}
