import SwiftUI

@main struct ProfileLayoutHost: App {
    @State private var maxHorizontalOffset: CGFloat = 0
    private let clock = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                NavigationLink("打开用户资料") {
                    ProfileFixture(description: String(repeating: "描述", count: 100), remarks: String(repeating: "备注", count: 25))
                        .navigationTitle("用户资料")
                        .navigationBarTitleDisplayMode(.inline)
                        .overlay(alignment: .top) {
                            Text(String(format: "%.3f", maxHorizontalOffset)).accessibilityIdentifier("horizontalOffset")
                        }
                        .onReceive(clock) { _ in
                            func collect(_ view: UIView) {
                                if let scroll = view as? UIScrollView { maxHorizontalOffset = max(maxHorizontalOffset, abs(scroll.contentOffset.x)) }
                                for child in view.subviews { collect(child) }
                            }
                            for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
                                for window in scene.windows { collect(window) }
                            }
                        }
                }
            }
        }
    }
}
