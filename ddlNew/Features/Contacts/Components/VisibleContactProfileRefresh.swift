import SwiftUI

/// 只在前台可见行发起静默刷新；两个列表共享 ContactsStore 的去重与限流。
struct VisibleContactProfileRefresh: ViewModifier {
    let friendUID: String?
    @ObservedObject var store: ContactsStore
    @ObservedObject private var authentication = IMUserAuthenticationService.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false

    func body(content: Content) -> some View {
        let activeID = visible && scenePhase == .active && authentication.isAuthenticated ? friendUID : nil
        content
            .onAppear { visible = true }
            .onDisappear { visible = false }
            .task(id: activeID) {
                guard let id = activeID else { return }
                while !Task.isCancelled {
                    await store.refreshVisibleProfile(id)
                    // 未拿到并发槽的可见行稍后重试；实际请求每个好友至少间隔30秒。
                    do { try await Task.sleep(nanoseconds: 5_000_000_000) }
                    catch { return }
                }
            }
    }
}
