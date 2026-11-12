import SwiftUI
struct FixtureMessage: Identifiable { let id: String; let height: CGFloat }
struct FixtureRoute { var targetMessageID: String? }
@MainActor final class FixtureStore: ObservableObject {
    @Published var messages: [FixtureMessage] = []
    @Published var initialHistoryRevision = 0
    var isVisible = true
    var isAtBottom = true
}
@main struct EntryHost: App {
    var body: some Scene { WindowGroup { NavigationStack {
        NavigationLink("打开测试群") { EntryScreen() }
    } } }
}
struct EntryScreen: View {
    @StateObject private var store = FixtureStore()
    let route = FixtureRoute()
    @State private var viewport = CGRect.zero
    @State private var latestLayout = ChatLatestPreference.Value()
    @State private var didInitialScroll = false
    @State private var alignedInitialHistoryRevision = 0
    @State private var followsInitialLatest = true
    @State private var resizeFollowTask: Task<Void, Never>?
    @State private var showTask = false
    @State private var showGroupTasks = false
    var latestFrame: CGRect { latestLayout.frame }
    var displayedMessages: [FixtureMessage] { store.messages }
    func updateVisibleMessages() {}
    func messageRow(_ message: FixtureMessage, previous: FixtureMessage?) -> some View {
        Text(message.id).frame(maxWidth: .infinity).frame(height: message.height)
            .background(Color.green.opacity(0.12)).id(message.id)
            .accessibilityIdentifier(message.id)
            .contextMenu { Button("转为事项") { showTask = true }; Button("复制") {} }
    }
    var body: some View {
        let messages = displayedMessages
        let initialHistoryRevision = store.initialHistoryRevision
        ScrollViewReader { proxy in
            VStack {
                HStack { Text("群公告"); Button("群事项") { showGroupTasks = true } }
                // PRODUCTION_SCROLL
                .coordinateSpace(name: "chatViewport")
                .background(GeometryReader { geo in Color.clear.onAppear {
                    viewport = CGRect(origin: .zero, size: geo.size); positionInitialMessages(proxy)
                }.onChange(of: geo.size) { size in
                    viewport = CGRect(origin: .zero, size: size); positionInitialMessages(proxy)
                } })
                .onPreferenceChange(ChatLatestPreference.self) { layout in
                    latestLayout = layout; positionInitialMessages(proxy)
                }
                .opacity(initialMessagesReady ? 1 : 0)
                .overlay { if !initialMessagesReady { ProgressView("正在加载") } }
            }
            .safeAreaInset(edge: .bottom) { Text("输入框").frame(maxWidth: .infinity).frame(height: 88) }
            .onChange(of: store.messages.last?.id) { _ in positionInitialMessages(proxy) }
            .task {
                store.messages = (0..<100).map { FixtureMessage(id: "message-\($0)", height: $0 == 99 ? 50 : CGFloat([60, 480, 90, 300, 140][$0 % 5])) }
                store.initialHistoryRevision = 1
            }
        }
        .navigationTitle("测试群")
        .navigationDestination(isPresented: $showTask) { Text("事项编辑") }
        .navigationDestination(isPresented: $showGroupTasks) { Text("群事项列表") }
    }
    // PRODUCTION_METHODS
}
extension BinaryInteger { func zoom() -> CGFloat { CGFloat(self) } }
