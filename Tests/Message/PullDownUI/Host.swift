import SwiftUI
@main struct PullDownHost: App {
    @State private var presentation = MessagePullDownState()
    var body: some Scene { WindowGroup {
        TabView {
            NavigationStack {
                List {
                    Text("消息列表顶部").frame(height: 100)
                        .background(MessagePullDownGesture(state: presentation, onBegin: {}))
                    ForEach(0..<80, id: \.self) { id in
                        Text("会话 \(id)").frame(height: 64)
                            .swipeActions { Button("删除", role: .destructive) {} }
                    }
                }
                .accessibilityIdentifier("conversations")
                .navigationTitle("消息")
                .navigationBarTitleDisplayMode(.inline)
            }.tabItem { Label("消息", systemImage: "message") }
            Text("其他页面").tabItem { Label("我的", systemImage: "person") }
        }.modifier(MessagePullDownPresentation(state: presentation))
    } }
}
enum MessagingTheme {
    static let surface = Color(uiColor: .systemBackground)
    static let secondaryText = Color.secondary
}
enum L10n { static func tr(_ key: String) -> String { key } }
